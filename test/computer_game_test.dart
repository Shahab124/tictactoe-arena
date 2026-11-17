import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/game/ai_client.dart';
import 'package:tictactoe_arena/game/game_screen.dart';
import 'package:tictactoe_arena/game/setup_screen.dart';

Future<GameStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return GameStore(
      firestore: FakeFirebaseFirestore(),
      prefs: await SharedPreferences.getInstance());
}

Future<GameStore> open(WidgetTester tester,
    {String difficulty = 'hard', AiClient ai = localAi}) async {
  final store = await newStore();
  await tester.pumpWidget(MaterialApp(
      home: GameScreen(size: 3, store: store, difficulty: difficulty, ai: ai)));
  return store;
}

Finder cell(int r, int c) =>
    find.bySemanticsLabel(RegExp('^Row ${r + 1}, column ${c + 1},'));

final os = find.bySemanticsLabel(RegExp(r', O$'));
final empties = find.bySemanticsLabel(RegExp(r', empty$'));

const failed = 'The computer could not make a move';

void main() {
  testWidgets('setup starts a game against the computer at the chosen level',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final store = await newStore();
    await tester.pumpWidget(MaterialApp(home: SetupScreen(store: store)));
    await tester.tap(find.text('Computer'));
    await tester.pump();
    await tester.tap(find.text('Hard'));
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    expect(find.text('Your turn'), findsOneWidget);
    expect(find.text('Computer'), findsOneWidget);

    // Take the first empty cell each turn; Hard never loses on 3×3.
    while (find.text('Your turn').evaluate().isNotEmpty) {
      await tester.tap(empties.first);
      await tester.pumpAndSettle();
    }
    final saved = (await store.history()).single;
    expect(saved.mode, 'computer');
    expect(saved.opponent, 'Computer (Hard)');
    expect(saved.result, isIn(['loss', 'draw']));
  });

  testWidgets('shows "Computer is thinking…" and then the computer\'s move',
      (tester) async {
    await open(tester);
    await tester.tap(cell(1, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Computer is thinking…'), findsOneWidget);

    // The player cannot move for the computer.
    await tester.tap(cell(0, 0));
    await tester.pump();
    expect(find.bySemanticsLabel('Row 1, column 1, empty'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(os, findsOneWidget);
    expect(find.text('Your turn'), findsOneWidget);
  });

  testWidgets('an AI error leaves the board unchanged and Retry asks again',
      (tester) async {
    var broken = true;
    await open(tester,
        ai: (request) async => broken
            ? {'error': 'INVALID_BOARD', 'message': 'test'}
            : localAi(request));
    await tester.tap(cell(1, 1));
    await tester.pumpAndSettle();
    expect(find.text(failed), findsOneWidget);
    expect(os, findsNothing);
    expect(find.text('End game'), findsOneWidget);

    // No moves count until the computer has played.
    await tester.tap(cell(0, 0));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Row 1, column 1, empty'), findsOneWidget);

    broken = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(os, findsOneWidget);
    expect(find.text('Your turn'), findsOneWidget);
  });

  testWidgets('an illegal move from the AI is refused by the engine',
      (tester) async {
    // (1, 1) is the cell the player has just taken.
    await open(tester, ai: (_) async => {'row': 1, 'col': 1});
    await tester.tap(cell(1, 1));
    await tester.pumpAndSettle();
    expect(find.text(failed), findsOneWidget);
    expect(find.bySemanticsLabel('Row 2, column 2, X'), findsOneWidget);
    expect(os, findsNothing);
  });

  testWidgets('an AI that crashes or sends nonsense is handled the same way',
      (tester) async {
    await open(tester, ai: (_) async => throw StateError('boom'));
    await tester.tap(cell(1, 1));
    await tester.pumpAndSettle();
    expect(find.text(failed), findsOneWidget);
  });

  testWidgets('no answer within the time limit is cancelled', (tester) async {
    await open(tester, ai: (_) => Completer<Map<String, Object>>().future);
    await tester.tap(cell(1, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Computer is thinking…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text(failed), findsOneWidget);
    expect(os, findsNothing);
  });

  testWidgets('End game leaves the game without saving it', (tester) async {
    final store = await newStore();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GameScreen(
                  size: 3,
                  store: store,
                  difficulty: 'easy',
                  ai: (_) async => {'error': 'X', 'message': 'test'}))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(cell(0, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End game'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(await store.history(), isEmpty);
  });

  testWidgets('Restart while the computer is thinking starts a clean game',
      (tester) async {
    await open(tester);
    await tester.tap(cell(1, 1));
    await tester.pump();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(find.text('Your turn'), findsOneWidget);
    expect(empties, findsNWidgets(9));
  });
}
