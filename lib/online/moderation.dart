import 'package:cloud_firestore/cloud_firestore.dart';

/// One player's report about another (REQ-ONL-08).
class Report {
  Report.fromMap(this.id, Map<String, dynamic> d)
      : reporter = d['reporter'] as String,
        reported = d['reported'] as String,
        room = d['room'] as String?,
        reason = d['reason'] as String? ?? '';

  final String id, reporter, reported, reason;
  final String? room;
}

/// Blocking, reporting, and the admin tools to review reports and suspend
/// accounts (REQ-ONL-08, REQ-ADM-01, REQ-ADM-03).
///
/// Admins are listed at `admins/<uid>`, added by hand in the Firebase
/// console; nothing in the app can make someone an admin. A suspended player
/// (`suspended/<uid>`) can't create, join or queue for online games, which
/// the database rules enforce.
class Moderation {
  Moderation(this.firestore);

  final FirebaseFirestore firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      firestore.collection('users').doc(uid);

  /// Reports [reported] after the online game in [room].
  Future<void> report(String reporter, String reported,
          {String? room, String reason = ''}) =>
      firestore.collection('reports').add({
        'reporter': reporter,
        'reported': reported,
        'room': room,
        'reason': reason,
        'status': 'open',
        'at': FieldValue.serverTimestamp(),
      });

  /// Blocks [other], so matchmaking never pairs them with [uid] again.
  Future<void> block(String uid, String other) => _user(uid).set({
        'blocked': FieldValue.arrayUnion([other])
      }, SetOptions(merge: true));

  Future<Set<String>> blocked(String uid) async =>
      {...?((await _user(uid).get()).data()?['blocked'] as List?)?.cast<String>()};

  Future<bool> isAdmin(String uid) async =>
      (await firestore.collection('admins').doc(uid).get()).exists;

  Future<bool> isSuspended(String uid) async =>
      (await firestore.collection('suspended').doc(uid).get()).exists;

  /// Reports still waiting for an admin, oldest first.
  Future<List<Report>> openReports() async => [
        for (final d in (await firestore
                .collection('reports')
                .where('status', isEqualTo: 'open')
                .get())
            .docs)
          Report.fromMap(d.id, d.data())
      ];

  /// Suspends the reported player and closes the report.
  Future<void> suspend(Report r, String admin) async {
    final batch = firestore.batch()
      ..set(firestore.collection('suspended').doc(r.reported),
          {'by': admin, 'report': r.id, 'at': FieldValue.serverTimestamp()})
      ..update(firestore.collection('reports').doc(r.id),
          {'status': 'suspended', 'closedBy': admin});
    await batch.commit();
  }

  /// Closes a report without action.
  Future<void> dismiss(Report r, String admin) => firestore
      .collection('reports')
      .doc(r.id)
      .update({'status': 'dismissed', 'closedBy': admin});
}
