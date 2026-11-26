import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_engine/game_engine.dart';

/// How long a player has to move before the other player can claim the win
/// (REQ-ONL-06). Also covers a player whose connection drops for good.
const turnLimit = Duration(seconds: 60);

/// One online game, stored at `rooms/<code>` (REQ-MODE-03).
///
/// Moves are kept in order as `row * size + col`, so the board, whose turn it
/// is and the winner can all be worked out from them. X always moves first.
class Room {
  Room.fromMap(this.code, Map<String, dynamic> d)
      : size = d['size'] as int,
        winLength = d['winLength'] as int,
        x = d['x'] as String,
        o = d['o'] as String?,
        moves = List<int>.from(d['moves'] as List),
        status = d['status'] as String,
        winner = d['winner'] as String?,
        reason = d['reason'] as String?,
        lastMoveAt = (d['lastMoveAt'] as Timestamp?)?.toDate();

  final String code;
  final int size, winLength;
  final String x;
  final String? o;
  final List<int> moves;

  /// 'waiting' for a second player, 'playing', or 'over'.
  final String status;

  /// 'X', 'O' or 'draw' once the game is over.
  final String? winner;

  /// Why it ended: 'line', 'draw', 'left' or 'timeout'.
  final String? reason;
  final DateTime? lastMoveAt;

  Mark get turn => moves.length.isEven ? Mark.x : Mark.o;
  Mark? markOf(String uid) => uid == x ? Mark.x : (uid == o ? Mark.o : null);

  Game toGame() {
    final game = Game(size: size, winLength: winLength);
    for (final m in moves) {
      game.play(m ~/ size, m % size);
    }
    return game;
  }

  /// True when the player to move has run out of time.
  bool timedOut(DateTime now) =>
      status == 'playing' &&
      lastMoveAt != null &&
      now.difference(lastMoveAt!) > turnLimit;
}

/// Thrown when a room code can't be used; [message] is shown to the player.
class RoomException implements Exception {
  RoomException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Creates, joins and plays online rooms. Firestore pushes each change to
/// both players straight away, and keeps a local copy so a short drop
/// doesn't lose a move (REQ-ONL-04, 05).
class OnlineRooms {
  OnlineRooms(this.firestore, {Random? random})
      : _random = random ?? Random.secure();

  final FirebaseFirestore firestore;
  final Random _random;

  // No 0/O or 1/I, so codes are easy to read out.
  static const _letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _rooms =>
      firestore.collection('rooms');

  /// Makes a new room and returns its 5-letter code.
  Future<String> create(String uid, {int size = 3, int? winLength}) async {
    final length = winLength ?? (size == 3 ? 3 : 5);
    Game(size: size, winLength: length); // Throws on a bad size or length.
    for (var tries = 0; tries < 5; tries++) {
      final code = List.generate(
          5, (_) => _letters[_random.nextInt(_letters.length)]).join();
      final ref = _rooms.doc(code);
      final taken = await firestore.runTransaction((t) async {
        if ((await t.get(ref)).exists) return true;
        t.set(ref, {
          'size': size,
          'winLength': length,
          'x': uid,
          'o': null,
          'players': [uid],
          'moves': <int>[],
          'status': 'waiting',
          'winner': null,
          'reason': null,
          'lastMoveAt': null,
        });
        return false;
      });
      if (!taken) return code;
    }
    throw RoomException('Could not make a room. Try again.');
  }

  /// Joins the room with [code] as O, or rejoins it if [uid] is already in it.
  Future<void> join(String code, String uid) async {
    final ref = _rooms.doc(code.trim().toUpperCase());
    await firestore.runTransaction((t) async {
      final snap = await t.get(ref);
      if (!snap.exists) throw RoomException('No room with that code.');
      final room = Room.fromMap(snap.id, snap.data()!);
      if (room.markOf(uid) != null) return; // Rejoining.
      if (room.status != 'waiting') throw RoomException('That room is full.');
      t.update(ref, {
        'o': uid,
        'players': [room.x, uid],
        'status': 'playing',
        'lastMoveAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<Room?> watch(String code) => _rooms.doc(code).snapshots().map(
      (s) => s.exists ? Room.fromMap(s.id, s.data()!) : null);

  /// The game [uid] is still playing, if any, so they can rejoin it.
  Future<Room?> unfinished(String uid) async {
    final snap = await _rooms
        .where('players', arrayContains: uid)
        .where('status', isEqualTo: 'playing')
        .get();
    return snap.docs.isEmpty
        ? null
        : Room.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// Plays [uid]'s move. Does nothing if it isn't their turn or the cell is
  /// taken.
  Future<void> move(Room room, String uid, int row, int col) async {
    if (room.status != 'playing' || room.markOf(uid) != room.turn) return;
    final game = room.toGame();
    if (game.play(row, col) != MoveResult.ok) return;
    final over = switch (game.status) {
      GameStatus.xWon => {'status': 'over', 'winner': 'X', 'reason': 'line'},
      GameStatus.oWon => {'status': 'over', 'winner': 'O', 'reason': 'line'},
      GameStatus.draw => {'status': 'over', 'winner': 'draw', 'reason': 'draw'},
      GameStatus.inProgress => <String, String>{},
    };
    await _rooms.doc(room.code).update({
      'moves': FieldValue.arrayUnion([row * room.size + col]),
      'lastMoveAt': FieldValue.serverTimestamp(),
      ...over,
    });
  }

  /// [uid] leaves a game in progress and loses it (REQ-ONL-06).
  Future<void> leave(Room room, String uid) async {
    final mark = room.markOf(uid);
    if (room.status != 'playing' || mark == null) return;
    await _rooms.doc(room.code).update(
        {'status': 'over', 'winner': mark.other.symbol, 'reason': 'left'});
  }

  /// [uid] claims the win because the other player ran out of time.
  Future<void> claimTimeout(Room room, String uid, {DateTime? now}) async {
    final mark = room.markOf(uid);
    if (mark == null || room.turn == mark) return;
    if (!room.timedOut(now ?? DateTime.now())) return;
    await _rooms.doc(room.code).update(
        {'status': 'over', 'winner': mark.symbol, 'reason': 'timeout'});
  }
}
