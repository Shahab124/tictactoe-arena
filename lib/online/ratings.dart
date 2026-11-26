import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'online_rooms.dart';

/// Every player starts here (REQ-RANK-01).
const startRating = 1200;
const _k = 32;

/// Elo change for a player rated [mine] against [theirs]; [score] is 1 for a
/// win, 0.5 for a draw and 0 for a loss.
int eloChange(int mine, int theirs, double score) {
  final expected = 1 / (1 + pow(10, (theirs - mine) / 400));
  return (_k * (score - expected)).round();
}

/// ISO week, e.g. '2026-W48', used for the weekly leaderboard.
String weekKey(DateTime d) {
  final day = DateTime.utc(d.year, d.month, d.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final week = (thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7) + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// One row of a leaderboard.
class Rating {
  Rating.fromMap(this.uid, Map<String, dynamic> d)
      : name = d['name'] as String? ?? 'Player',
        rating = d['rating'] as int? ?? startRating,
        games = d['games'] as int? ?? 0,
        week = d['week'] as String?,
        weekPoints = d['weekPoints'] as int? ?? 0,
        lastRoom = d['lastRoom'] as String?,
        previous = d['previous'] as int?;

  final String uid, name;
  final int rating, games, weekPoints;
  final String? week;

  /// The last game counted, and the rating just before it.
  final String? lastRoom;
  final int? previous;

  /// This player's rating before [code] was counted, so both players' changes
  /// use the ratings from before the game, whoever records first.
  int ratingBefore(String code) => lastRoom == code ? previous ?? rating : rating;
}

/// Ratings and leaderboards, stored at `ratings/<uid>` (REQ-RANK-01, 02).
///
/// Every online game is ranked. When it ends, each player updates their own
/// rating once; the database rules check the game is over, that they played in
/// it, and that it hasn't been counted before.
// ponytail: each client works out its own Elo, so a determined cheater could
// send a wrong number. Move the maths to a Cloud Function if that matters.
class Ratings {
  Ratings(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _ratings =>
      firestore.collection('ratings');

  Future<Rating> of(String uid) async =>
      Rating.fromMap(uid, (await _ratings.doc(uid).get()).data() ?? {});

  /// Counts the finished [room] for [uid]. Safe to call more than once.
  Future<void> record(Room room, String uid, {DateTime? now}) async {
    final me = room.markOf(uid);
    final opponent = me == null ? null : (uid == room.x ? room.o : room.x);
    if (room.status != 'over' || me == null || opponent == null) return;
    final score = switch (room.winner) {
      'draw' => 0.5,
      final w when w == me.symbol => 1.0,
      _ => 0.0,
    };
    final week = weekKey(now ?? DateTime.now());
    final name = (await firestore.collection('users').doc(uid).get())
        .data()?['username'] as String?;

    final mine = _ratings.doc(uid);
    final marker = mine.collection('rated').doc(room.code);
    await firestore.runTransaction((t) async {
      if ((await t.get(marker)).exists) return;
      final old = Rating.fromMap(uid, (await t.get(mine)).data() ?? {});
      final theirs =
          Rating.fromMap(opponent, (await t.get(_ratings.doc(opponent))).data() ?? {});
      t.set(marker, {'at': FieldValue.serverTimestamp()});
      t.set(mine, {
        'name': name ?? old.name,
        'rating': old.rating +
            eloChange(old.rating, theirs.ratingBefore(room.code), score),
        'previous': old.rating,
        'games': old.games + 1,
        'week': week,
        'weekPoints': (old.week == week ? old.weekPoints : 0) +
            (score == 1 ? 3 : score == 0.5 ? 1 : 0),
        'lastRoom': room.code,
      });
    });
  }

  /// Highest ratings of all time.
  Future<List<Rating>> global({int limit = 20}) async => [
        for (final d in (await _ratings
                .orderBy('rating', descending: true)
                .limit(limit)
                .get())
            .docs)
          Rating.fromMap(d.id, d.data())
      ];

  /// Most points this week: 3 for a win, 1 for a draw.
  // ponytail: sorted on the device to avoid a composite index; fine for a
  // class-sized player base, add an index past a few thousand players.
  Future<List<Rating>> weekly({DateTime? now, int limit = 20}) async {
    final rows = [
      for (final d in (await _ratings
              .where('week', isEqualTo: weekKey(now ?? DateTime.now()))
              .get())
          .docs)
        Rating.fromMap(d.id, d.data())
    ]..sort((a, b) => b.weekPoints.compareTo(a.weekPoints));
    return rows.take(limit).toList();
  }
}
