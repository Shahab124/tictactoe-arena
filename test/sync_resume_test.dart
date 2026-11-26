import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_record.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/game/game_screen.dart';
import 'package:tictactoe_arena/game/setup_screen.dart';

// SCRUM-26: settings follow the account, offline games upload without
// duplicates, and an unfinished game can be continued on another device.

/// A device: its own on-device storage, sharing the account's [firestore].
Future<GameStore> device(FakeFirebaseFirestore firestore) async {
  SharedPreferences.setMockInitialValues({});
  return GameStore(
      firestore: firestore, prefs: await SharedPreferences.getInstance());
}

Finder cell(int r, int c) =>
    find.bySemanticsLabel(RegExp('^Row ${r + 1}, column ${c + 1},'));

final record = GameRecord(
  boardSize: 3,
  winLength: 3,
  mode: 'local',
  opponent: 'Local player',
  moves: const [(0, 0), (1, 1), (0, 1)],
  result: 'win',
  playedAt: DateTime.utc(2026, 11, 19, 10),
);

void tallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 2000);
  addTearDown(tester.view.reset);
}

void main() {
  test('a game uploaded twice after reconnecting is saved once', () async {
    final firestore = FakeFirebaseFirestore();
    final store = await device(firestore);
    await store.save(record, uid: 'u1');
    await store.save(record, uid: 'u1'); // retried upload
    await Future<void>.delayed(Duration.zero);
    expect((await store.history(uid: 'u1')).length, 1);
  });

  test('guest games moved into an account that already has them are not '
      'duplicated', () async {
    final firestore = FakeFirebaseFirestore();
    final store = await device(firestore);
    await store.save(record, uid: 'u1');
    await store.save(record); // the same game also kept on the device
    await store.moveGuestGames('u1');
    await Future<void>.delayed(Duration.zero);
    expect((await store.history(uid: 'u1')).length, 1);
  });

  testWidgets('setup choices follow the account to a new device',
      (tester) async {
    tallView(tester);
    final firestore = FakeFirebaseFirestore();
    final phone = await device(firestore);
    await tester.pumpWidget(
        MaterialApp(home: SetupScreen(store: phone, uid: 'u1')));
    await tester.pumpAndSettle();
    expect(find.text('Difficulty'), findsNothing);
    await tester.tap(find.text('Computer'));
    await tester.pump();
    await tester.tap(find.text('Hard'));
    await tester.tap(find.text('Best of 3'));
    await tester.pump();
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    final tablet = await device(firestore);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
        MaterialApp(home: SetupScreen(store: tablet, uid: 'u1')));
    await tester.pumpAndSettle();
    expect(find.text('Difficulty'), findsOneWidget); // Computer mode
    expect(await tablet.loadSettings(uid: 'u1'), containsPair('bestOf', 3));
    expect(await tablet.loadSettings(uid: 'u1'),
        containsPair('difficulty', 'hard'));
  });

  testWidgets('an unfinished game continues on another device, then clears',
      (tester) async {
    tallView(tester);
    final firestore = FakeFirebaseFirestore();
    final phone = await device(firestore);
    await tester.pumpWidget(
        MaterialApp(home: GameScreen(size: 3, store: phone, uid: 'u1')));
    await tester.tap(cell(0, 0)); // X
    await tester.pump();
    await tester.tap(cell(1, 1)); // O
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox()); // app closed

    final tablet = await device(firestore);
    await tester.pumpWidget(
        MaterialApp(home: SetupScreen(store: tablet, uid: 'u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue unfinished game'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Row 1, column 1, X'), findsOneWidget);
    expect(find.bySemanticsLabel('Row 2, column 2, O'), findsOneWidget);
    expect(find.text("X's turn"), findsOneWidget);

    // X wins along the top row; the finished game is no longer offered.
    for (final (r, c) in [(0, 1), (2, 2), (0, 2)]) {
      await tester.tap(cell(r, c));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('X wins!'), findsOneWidget);
    expect(await tablet.loadCurrent(uid: 'u1'), isNull);
    expect((await tablet.history(uid: 'u1')).length, 1);
  });

  testWidgets("a guest's unfinished game is kept on the device",
      (tester) async {
    tallView(tester);
    final store = await device(FakeFirebaseFirestore());
    await tester.pumpWidget(MaterialApp(home: GameScreen(size: 3, store: store)));
    await tester.tap(cell(2, 0));
    await tester.pumpAndSettle();
    final saved = await store.loadCurrent();
    expect(saved?['moves'], [
      {'r': 2, 'c': 0}
    ]);
  });
}
