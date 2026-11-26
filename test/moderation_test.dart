import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_arena/online/admin_screen.dart';
import 'package:tictactoe_arena/online/matchmaking.dart';
import 'package:tictactoe_arena/online/moderation.dart';
import 'package:tictactoe_arena/online/online_rooms.dart';
import 'package:tictactoe_arena/online/online_screen.dart';
import 'package:tictactoe_arena/online/ratings.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late Moderation mod;

  setUp(() {
    fs = FakeFirebaseFirestore();
    mod = Moderation(fs);
  });

  test('a report is stored as open for admins to review', () async {
    await mod.report('ayesha', 'omar', room: 'ABCDE', reason: 'rude name');
    final reports = await mod.openReports();
    expect(reports.single.reported, 'omar');
    expect(reports.single.reason, 'rude name');
  });

  test('suspending closes the report and blocks online play; dismiss closes it', () async {
    await mod.report('ayesha', 'omar');
    await mod.report('zara', 'ali');
    final [first, second] = await mod.openReports();
    await mod.suspend(first, 'boss');
    await mod.dismiss(second, 'boss');

    expect(await mod.openReports(), isEmpty);
    expect(await mod.isSuspended(first.reported), isTrue);
    expect(await mod.isSuspended(second.reported), isFalse);
  });

  test('admins are only those listed in admins/', () async {
    await fs.doc('admins/boss').set({'since': 1});
    expect(await mod.isAdmin('boss'), isTrue);
    expect(await mod.isAdmin('ayesha'), isFalse);
  });

  test('matchmaking never pairs a player with someone they blocked', () async {
    await mod.block('me', 'troll');
    await fs.doc('queue/troll').set({
      'rating': 1200, 'size': 3, 'since': Timestamp.now(), 'room': null,
    });
    final mm = Matchmaker(fs, Ratings(fs));
    expect(await mm.findOrWait('me'), isNull);
    expect(await mod.blocked('me'), {'troll'});
  });

  testWidgets('admin screen lists reports and suspends with one tap', (tester) async {
    await mod.report('ayesha', 'omar', reason: 'spam');
    await tester.pumpWidget(MaterialApp(home: AdminScreen(moderation: mod, uid: 'boss')));
    await tester.pumpAndSettle();
    expect(find.text('Reported player: omar'), findsOneWidget);

    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    expect(find.text('No open reports.'), findsOneWidget);
    expect(await mod.isSuspended('omar'), isTrue);
  });

  testWidgets('lobby shows the admin button only to admins and warns suspended players',
      (tester) async {
    await fs.doc('admins/boss').set({'since': 1});
    await fs.doc('suspended/omar').set({'by': 'boss'});
    final rooms = OnlineRooms(fs);

    await tester.pumpWidget(MaterialApp(
        home: OnlineLobby(rooms: rooms, ratings: Ratings(fs), uid: 'boss')));
    await tester.pumpAndSettle();
    expect(find.text('Admin dashboard'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
        home: OnlineLobby(
            key: const ValueKey('omar'), rooms: rooms, ratings: Ratings(fs), uid: 'omar')));
    await tester.pumpAndSettle();
    expect(find.text('Admin dashboard'), findsNothing);
    expect(find.textContaining('suspended'), findsOneWidget);
  });

  testWidgets('after an online game a player can report or block the other', (tester) async {
    await fs.doc('rooms/ABCDE').set({
      'size': 3, 'winLength': 3, 'x': 'ayesha', 'o': 'omar', 'players': ['ayesha', 'omar'],
      'moves': [0, 3, 1, 4, 2], 'status': 'over', 'winner': 'X', 'reason': 'line',
      'lastMoveAt': null,
    });
    await tester.pumpWidget(MaterialApp(
        home: RoomScreen(
            rooms: OnlineRooms(fs), ratings: Ratings(fs), uid: 'omar', code: 'ABCDE')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Blocked'), findsOneWidget);
    expect(await mod.blocked('omar'), {'ayesha'});
  });
}
