import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'ratings.dart';

/// How far apart two ratings may be: 100 points at first, widening by 50
/// for every 10 seconds the waiting player has been in the queue (REQ-ONL-01).
/// A negative wait (the device clock behind the server's) counts as zero.
int allowedGap(Duration waited) =>
    100 + 50 * (waited.isNegative ? 0 : waited.inSeconds ~/ 10);

/// Pairs players of similar rating, using `queue/<uid>` docs.
///
/// A player who finds nobody waits in the queue. The next player to search
/// picks the closest waiting player within [allowedGap], creates a room as X
/// and writes its code into the waiting player's queue doc; that player then
/// joins it as O. Leaving the queue deletes the doc.
class Matchmaker {
  Matchmaker(this.firestore, this.ratings, {Random? random})
      : _random = random ?? Random.secure();

  final FirebaseFirestore firestore;
  final Ratings ratings;
  final Random _random;

  static const _letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _queue =>
      firestore.collection('queue');

  /// Matches [uid] with a waiting player and returns the new room code, or
  /// puts [uid] in the queue and returns null.
  Future<String?> findOrWait(String uid, {int size = 3, DateTime? now}) async {
    final time = now ?? DateTime.now();
    final mine = (await ratings.of(uid)).rating;
    int gap(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
        ((d.data()['rating'] as int? ?? startRating) - mine).abs();
    final waiting = (await _queue
            .where('size', isEqualTo: size)
            .where('room', isNull: true)
            .get())
        .docs
        .where((d) {
          final since = (d.data()['since'] as Timestamp?)?.toDate() ?? time;
          return d.id != uid && gap(d) <= allowedGap(time.difference(since));
        })
        .toList()
      ..sort((a, b) => gap(a).compareTo(gap(b)));

    for (final candidate in waiting) {
      final code = await _pair(uid, candidate.reference, size);
      if (code != null) return code;
    }
    await _queue.doc(uid).set({
      'rating': mine,
      'size': size,
      'since': FieldValue.serverTimestamp(),
      'room': null,
    });
    return null;
  }

  // Creates a room with [uid] as X and hands its code to the waiting player,
  // unless someone else got to them first.
  Future<String?> _pair(
      String uid, DocumentReference<Map<String, dynamic>> other, int size) {
    final code = List.generate(
        5, (_) => _letters[_random.nextInt(_letters.length)]).join();
    final room = firestore.collection('rooms').doc(code);
    return firestore.runTransaction((t) async {
      final snap = await t.get(other);
      if (!snap.exists || snap.data()!['room'] != null) return null;
      if ((await t.get(room)).exists) return null;
      t.set(room, {
        'size': size,
        'winLength': size == 3 ? 3 : 5,
        'x': uid,
        'o': null,
        'players': [uid],
        'moves': <int>[],
        'status': 'waiting',
        'winner': null,
        'reason': null,
        'lastMoveAt': null,
      });
      t.update(other, {'room': code});
      return code;
    });
  }

  /// The room code once someone matches [uid], or null while still waiting.
  Stream<String?> matched(String uid) => _queue
      .doc(uid)
      .snapshots()
      .map((s) => s.data()?['room'] as String?);

  /// Leaves the queue (also used once matched).
  Future<void> leave(String uid) => _queue.doc(uid).delete();
}
