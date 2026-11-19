import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tictactoe_arena/data/game_record.dart';
import 'package:tictactoe_arena/data/history_screen.dart';
import 'package:tictactoe_arena/game/game_screen.dart';
import 'package:tictactoe_arena/game/replay_screen.dart';

import 'computer_game_test.dart' show cell, newStore, open;

/// Semantics value of the cell at (r, c), e.g. 'hint' or 'last move'.
String? valueOf(WidgetTester tester, int r, int c) =>
    tester.getSemantics(cell(r, c)).value;

// O missed the block at (0,2), so X won along the top row.
final blunder = GameRecord(
  boardSize: 3,
  winLength: 3,
  mode: 'local',
  opponent: 'Local player',
  moves: const [(0, 0), (1, 1), (0, 1), (2, 2), (0, 2)],
  result: 'win',
  playedAt: DateTime.utc(2026, 11, 19),
);

void main() {
  testWidgets('the computer shows it is thinking on its turn', (tester) async {
    await open(tester);
    await tester.tap(cell(0, 0));
    await tester.pump();
    expect(find.text('Computer is thinking…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Your turn'), findsOneWidget);
  });

  testWidgets('hint highlights the winning cell and clears after a move',
      (tester) async {
    final store = await newStore();
    await tester.pumpWidget(
        MaterialApp(home: GameScreen(size: 3, store: store)));
    // X: (0,0), (0,1); O: (1,0), (1,1). X to move can win at (0,2).
    for (final (r, c) in [(0, 0), (1, 0), (0, 1), (1, 1)]) {
      await tester.tap(cell(r, c));
      await tester.pump();
    }
    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();
    expect(valueOf(tester, 0, 2), 'hint');

    await tester.tap(cell(2, 2));
    await tester.pumpAndSettle();
    expect(valueOf(tester, 0, 2), isNot('hint'));
  });

  testWidgets('after a game, Replay steps through the moves', (tester) async {
    final store = await newStore();
    await tester.pumpWidget(
        MaterialApp(home: GameScreen(size: 3, store: store)));
    for (final (r, c) in blunder.moves) {
      await tester.tap(cell(r, c));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Hint'), findsNothing);
    await tester.tap(find.text('Replay'));
    await tester.pumpAndSettle();

    expect(find.text('Move 5 of 5 · X at row 1, column 3 · Best move'),
        findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('Move 4 of 5 · O at row 3, column 3 · Worst move'),
        findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('Move 3 of 5 · X at row 1, column 2'), findsOneWidget);
  });

  testWidgets('replay jumps to the best and worst moves', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReplayScreen(game: blunder)));
    await tester.tap(find.text('Show worst move'));
    await tester.pump();
    expect(find.textContaining('Move 4 of 5'), findsOneWidget);
    await tester.tap(find.text('Show best move'));
    await tester.pump();
    expect(find.textContaining('Move 5 of 5'), findsOneWidget);
  });

  testWidgets('replay keeps O as O when O moved first', (tester) async {
    final g = GameRecord.fromMap({...blunder.toMap(), 'firstMark': 'O'});
    await tester.pumpWidget(MaterialApp(home: ReplayScreen(game: g)));
    expect(find.textContaining('· O at row 1, column 3'), findsOneWidget);
  });

  testWidgets('a game in history opens its replay', (tester) async {
    final store = await newStore();
    await store.save(blunder);
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Local player'));
    await tester.pumpAndSettle();
    expect(find.text('Replay · vs Local player'), findsOneWidget);
  });
}
