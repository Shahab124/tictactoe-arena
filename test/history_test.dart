import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_record.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/data/history_screen.dart';

GameRecord game(String result,
        {int size = 3, String mode = 'computer', int day = 1}) =>
    GameRecord(
      boardSize: size,
      winLength: size == 3 ? 3 : 5,
      mode: mode,
      opponent: mode == 'computer' ? 'Computer (Easy)' : 'Local player',
      moves: const [(0, 0), (1, 1), (0, 1)],
      result: result,
      playedAt: DateTime.utc(2026, 11, day),
    );

Future<GameStore> newStore([FakeFirebaseFirestore? firestore]) async {
  SharedPreferences.setMockInitialValues({});
  return GameStore(
    firestore: firestore ?? FakeFirebaseFirestore(),
    prefs: await SharedPreferences.getInstance(),
  );
}

void main() {
  test('a game record survives a save and load unchanged', () {
    final g = game('win');
    final back = GameRecord.fromMap(g.toMap());
    expect(back.toMap(), g.toMap());
    expect(back.moves, [(0, 0), (1, 1), (0, 1)]);
  });

  test("a signed-in player's games go to their own Firestore folder",
      () async {
    final firestore = FakeFirebaseFirestore();
    final store = await newStore(firestore);
    await store.save(game('win'), uid: 'ayesha');
    await Future<void>.delayed(Duration.zero);

    final docs = await firestore.collection('users/ayesha/games').get();
    expect(docs.docs.single.data()['result'], 'win');
    expect(await store.history(uid: 'omar'), isEmpty);
  });

  test('guest games stay on the device, not in Firestore', () async {
    final firestore = FakeFirebaseFirestore();
    final store = await newStore(firestore);
    await store.save(game('draw'));

    expect((await store.history()).single.result, 'draw');
    expect(firestore.dump(), isNot(contains('draw')));
  });

  test('history is newest first', () async {
    final store = await newStore();
    for (final day in [3, 1, 2]) {
      await store.save(game('win', day: day));
    }
    final days = [for (final g in await store.history()) g.playedAt.day];
    expect(days, [3, 2, 1]);
  });

  test('statistics are split by board size and mode', () {
    final stats = Stats.byBoardAndMode([
      game('win'),
      game('win'),
      game('loss'),
      game('draw'),
      game('loss', size: 8),
      game('win', mode: 'local'),
    ]);
    final easy3 = stats['3×3 computer']!;
    expect([easy3.played, easy3.wins, easy3.losses, easy3.draws], [4, 2, 1, 1]);
    expect(easy3.winRate, 0.5);
    expect(stats['8×8 computer']!.losses, 1);
    expect(stats['3×3 local']!.wins, 1);
    expect(Stats().winRate, 0);
  });

  testWidgets('history screen shows statistics and each game', (tester) async {
    final store = await newStore();
    await store.save(game('win'));
    await store.save(game('loss', size: 8, day: 2));

    await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 played · 1 won'), findsOneWidget);
    expect(find.text('3×3 computer'), findsOneWidget);
    expect(find.text('8×8 computer'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('LOSS'), findsOneWidget);
  });

  testWidgets('history screen says when there are no games', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: HistoryScreen(store: await newStore())));
    await tester.pumpAndSettle();
    expect(find.text('No games played yet.'), findsOneWidget);
  });
}
