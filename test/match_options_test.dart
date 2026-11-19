import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/game/game_screen.dart';
import 'package:tictactoe_arena/game/setup_screen.dart';

// SCRUM-24: 4 or 5 in a row, last-move marker, undo against the computer,
// X/O and who starts, and best-of-3/5 matches.

Future<GameStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return GameStore(
      firestore: FakeFirebaseFirestore(),
      prefs: await SharedPreferences.getInstance());
}

Finder cell(int r, int c) =>
    find.bySemanticsLabel(RegExp('^Row ${r + 1}, column ${c + 1},'));

final empties = find.bySemanticsLabel(RegExp(r', empty$'));
final xs = find.bySemanticsLabel(RegExp(r', X$'));
final os = find.bySemanticsLabel(RegExp(r', O$'));

/// A predictable computer: always takes the first empty cell.
Future<Map<String, Object>> firstEmpty(Map<String, dynamic> request) async {
  final board = request['board'] as List;
  for (var r = 0; r < board.length; r++) {
    for (var c = 0; c < board.length; c++) {
      if (board[r][c] == '') return {'row': r, 'col': c};
    }
  }
  return {'error': 'BOARD_FULL', 'message': 'test'};
}

Future<void> play(WidgetTester tester, List<(int, int)> moves) async {
  for (final (r, c) in moves) {
    await tester.tap(cell(r, c));
    await tester.pumpAndSettle();
  }
}

bool undoEnabled(WidgetTester tester) => tester
    .widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Undo'), matching: find.bySubtype<ButtonStyleButton>()))
    .enabled;

void main() {
  testWidgets('setup passes 4 in a row, X/O, who starts and best of 3',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2000);
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(MaterialApp(home: SetupScreen(store: await newStore())));
    await tester.tap(find.text('Big 8×8'));
    await tester.pump();
    await tester.tap(find.text('4 in a row'));
    await tester.pump();
    expect(find.text('Four in a row wins. Pinch the board to zoom.'),
        findsOneWidget);
    await tester.tap(find.text('Computer'));
    await tester.pump();
    await tester.tap(find.text('O').first);
    await tester.tap(find.text('Computer').last);
    await tester.tap(find.text('Best of 3'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.winLength, 4);
    expect(game.playerMark, Mark.o);
    expect(game.firstToMove, Mark.x);
    expect(game.bestOf, 3);
    expect(game.difficulty, 'medium');
    expect(find.text('Big 8×8 · four in a row'), findsOneWidget);
    // The computer (X) has already opened.
    expect(xs, findsOneWidget);
    expect(find.text('Your turn'), findsOneWidget);
  });

  testWidgets('four in a row wins on 8×8 when chosen', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: GameScreen(size: 8, winLength: 4, store: await newStore())));
    await play(tester, [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2)]);
    expect(find.text("X's turn"), findsOneWidget);
    await play(tester, [(0, 3)]);
    expect(find.text('X wins!'), findsOneWidget);
  });

  testWidgets('the last move is marked', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
        MaterialApp(home: GameScreen(size: 3, store: await newStore())));
    await play(tester, [(0, 0)]);
    expect(tester.getSemantics(cell(0, 0)).value, 'last move');
    await play(tester, [(2, 2)]);
    expect(tester.getSemantics(cell(2, 2)).value, 'last move');
    expect(tester.getSemantics(cell(0, 0)).value, '');
    handle.dispose();
  });

  testWidgets('undo takes back your move and the computer\'s reply',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: GameScreen(
            size: 3,
            store: await newStore(),
            difficulty: 'easy',
            ai: firstEmpty)));
    expect(undoEnabled(tester), isFalse);
    await play(tester, [(1, 1)]);
    expect(xs, findsOneWidget);
    expect(os, findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(empties, findsNWidgets(9));
    expect(find.text('Your turn'), findsOneWidget);
    expect(undoEnabled(tester), isFalse);
  });

  testWidgets(
      'playing O against a computer that starts, and the result is '
      'saved from your side', (tester) async {
    final store = await newStore();
    await tester.pumpWidget(MaterialApp(
        home: GameScreen(
            size: 3,
            store: store,
            difficulty: 'easy',
            ai: firstEmpty,
            playerMark: Mark.o,
            firstToMove: Mark.x)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Row 1, column 1, X'), findsOneWidget);
    expect(find.text('Your turn'), findsOneWidget);
    // Only the computer has moved, so there is nothing of yours to undo.
    expect(undoEnabled(tester), isFalse);

    // Computer takes (0,2) then (1,0); O completes the middle column.
    await play(tester, [(0, 1), (1, 1), (2, 1)]);
    expect(find.text('You win!'), findsOneWidget);
    final saved = (await store.history()).single;
    expect(saved.result, 'win');
  });

  testWidgets('best of 3 keeps a running score and ends the match',
      (tester) async {
    final store = await newStore();
    await tester.pumpWidget(
        MaterialApp(home: GameScreen(size: 3, store: store, bestOf: 3)));
    expect(find.text('Best of 3 · X 0 – 0 O'), findsOneWidget);

    const xWins = [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)];
    await play(tester, xWins);
    expect(find.text('X wins!'), findsOneWidget);
    expect(find.text('Best of 3 · X 1 – 0 O'), findsOneWidget);
    await tester.tap(find.text('Next game'));
    await tester.pumpAndSettle();

    await play(tester, xWins);
    expect(find.text('X wins the match!'), findsOneWidget);
    expect(find.text('Best of 3 · X 2 – 0 O'), findsOneWidget);
    expect(await store.history(), hasLength(2));

    await tester.tap(find.text('New match'));
    await tester.pumpAndSettle();
    expect(find.text('Best of 3 · X 0 – 0 O'), findsOneWidget);
    expect(empties, findsNWidgets(9));
  });

  testWidgets('O can start a local game', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home:
            GameScreen(size: 3, store: await newStore(), firstToMove: Mark.o)));
    expect(find.text("O's turn"), findsOneWidget);
    await play(tester, [(0, 0)]);
    expect(find.bySemanticsLabel('Row 1, column 1, O'), findsOneWidget);
  });
}
