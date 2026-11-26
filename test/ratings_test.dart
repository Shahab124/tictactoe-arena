import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_arena/online/leaderboard_screen.dart';
import 'package:tictactoe_arena/online/online_rooms.dart';
import 'package:tictactoe_arena/online/ratings.dart';

Room finished(String code, {String winner = 'X', String x = 'ayesha', String o = 'omar'}) =>
    Room.fromMap(code, {
      'size': 3,
      'winLength': 3,
      'x': x,
      'o': o,
      'moves': [0, 3, 1, 4, 2],
      'status': 'over',
      'winner': winner,
      'reason': winner == 'draw' ? 'draw' : 'line',
      'lastMoveAt': null,
    });

void main() {
  final monday = DateTime(2026, 11, 23);

  test('Elo: equal players gain and lose 16, upsets move more', () {
    expect(eloChange(1200, 1200, 1), 16);
    expect(eloChange(1200, 1200, 0), -16);
    expect(eloChange(1200, 1200, 0.5), 0);
    expect(eloChange(1000, 1400, 1), greaterThan(16));
    expect(eloChange(1400, 1000, 1), lessThan(16));
  });

  test('week keys follow ISO weeks', () {
    expect(weekKey(DateTime(2026, 11, 23)), '2026-W48');
    expect(weekKey(DateTime(2026, 11, 29)), '2026-W48');
    expect(weekKey(DateTime(2026, 11, 30)), '2026-W49');
    expect(weekKey(DateTime(2027, 1, 1)), '2026-W53');
  });

  test('a finished game changes both ratings once, using usernames', () async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('users/ayesha').set({'username': 'ayesha_k'});
    final ratings = Ratings(fs);
    final room = finished('ABCDE');

    await ratings.record(room, 'ayesha', now: monday);
    await ratings.record(room, 'omar', now: monday);
    await ratings.record(room, 'ayesha', now: monday); // Counted only once.

    final a = await ratings.of('ayesha');
    final o = await ratings.of('omar');
    expect([a.rating, a.games, a.weekPoints, a.name], [1216, 1, 3, 'ayesha_k']);
    expect([o.rating, o.games, o.weekPoints], [1184, 1, 0]);
  });

  test('a draw gives a weekly point and unfinished games are ignored', () async {
    final ratings = Ratings(FakeFirebaseFirestore());
    await ratings.record(finished('DRAWN', winner: 'draw'), 'ayesha', now: monday);
    final playing = Room.fromMap('LIVE1', {
      'size': 3, 'winLength': 3, 'x': 'ayesha', 'o': 'omar', 'moves': [0],
      'status': 'playing', 'winner': null, 'reason': null, 'lastMoveAt': null,
    });
    await ratings.record(playing, 'ayesha', now: monday);
    final a = await ratings.of('ayesha');
    expect([a.rating, a.games, a.weekPoints], [1200, 1, 1]);
  });

  test('weekly points start again in a new week', () async {
    final ratings = Ratings(FakeFirebaseFirestore());
    await ratings.record(finished('WEEK1'), 'ayesha', now: monday);
    await ratings.record(finished('WEEK2'), 'ayesha', now: monday.add(const Duration(days: 7)));
    final a = await ratings.of('ayesha');
    expect(a.games, 2);
    expect(a.weekPoints, 3);
  });

  test('leaderboards are ordered by rating and by this week\'s points', () async {
    final fs = FakeFirebaseFirestore();
    final week = weekKey(monday);
    await fs.doc('ratings/a').set({'name': 'Ali', 'rating': 1250, 'games': 3, 'week': week, 'weekPoints': 3});
    await fs.doc('ratings/b').set({'name': 'Sara', 'rating': 1300, 'games': 2, 'week': '2026-W40', 'weekPoints': 9});
    await fs.doc('ratings/c').set({'name': 'Zain', 'rating': 1180, 'games': 4, 'week': week, 'weekPoints': 6});
    final ratings = Ratings(fs);

    expect([for (final r in await ratings.global()) r.name], ['Sara', 'Ali', 'Zain']);
    expect([for (final r in await ratings.weekly(now: monday)) r.name], ['Zain', 'Ali']);
  });

  testWidgets('leaderboard screen lists players and marks you', (tester) async {
    final fs = FakeFirebaseFirestore();
    await fs.doc('ratings/a').set({'name': 'Ali', 'rating': 1250, 'games': 3});
    await fs.doc('ratings/me').set({'name': 'Omar', 'rating': 1210, 'games': 1});
    await tester.pumpWidget(MaterialApp(
        home: LeaderboardScreen(ratings: Ratings(fs), uid: 'me')));
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Omar (you)'), findsOneWidget);
    expect(find.text('1250'), findsOneWidget);

    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No ranked games yet'), findsOneWidget);
  });
}
