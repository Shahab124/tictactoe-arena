import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/game/game_screen.dart';

Future<GameStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return GameStore(
      firestore: FakeFirebaseFirestore(),
      prefs: await SharedPreferences.getInstance());
}

Future<GameStore> open(WidgetTester tester, {int size = 3}) async {
  final store = await newStore();
  await tester.pumpWidget(
      MaterialApp(home: GameScreen(size: size, store: store)));
  return store;
}

Finder cell(int r, int c) => find.bySemanticsLabel(RegExp('^Row ${r + 1}, column ${c + 1},'));

Future<void> play(WidgetTester tester, List<(int, int)> moves) async {
  for (final (r, c) in moves) {
    await tester.tap(cell(r, c));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('shows whose turn it is and places marks', (tester) async {
    await open(tester);
    expect(find.text("X's turn"), findsOneWidget);
    await play(tester, [(1, 1)]);
    expect(find.bySemanticsLabel('Row 2, column 2, X'), findsOneWidget);
    expect(find.text("O's turn"), findsOneWidget);
  });

  testWidgets('a taken cell is refused with a message', (tester) async {
    await open(tester);
    await play(tester, [(0, 0), (0, 0)]);
    expect(find.text('That cell is already taken'), findsOneWidget);
    expect(find.text("O's turn"), findsOneWidget);
  });

  testWidgets('a win is announced, saved, and no more moves count',
      (tester) async {
    final store = await open(tester);
    await play(tester, [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)]);
    expect(find.text('X wins!'), findsOneWidget);
    expect(find.text('Rematch'), findsOneWidget);

    await play(tester, [(2, 2)]);
    expect(find.bySemanticsLabel('Row 3, column 3, empty'), findsOneWidget);

    final saved = await store.history();
    expect(saved.single.result, 'win');
    expect(saved.single.mode, 'local');
    expect(saved.single.moves.length, 5);
  });

  testWidgets('a draw is announced and saved', (tester) async {
    final store = await open(tester);
    await play(tester, [
      (0, 0), (0, 1), (0, 2), (1, 1), (1, 0), (1, 2), (2, 1), (2, 0), (2, 2),
    ]);
    expect(find.text("It's a draw"), findsOneWidget);
    expect((await store.history()).single.result, 'draw');
  });

  testWidgets('rematch starts a fresh game with one tap', (tester) async {
    await open(tester);
    await play(tester, [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)]);
    await tester.tap(find.text('Rematch'));
    await tester.pumpAndSettle();
    expect(find.text("X's turn"), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(', [XO]\$')), findsNothing);
  });

  testWidgets('8×8 has 64 cells and needs five in a row', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.reset);
    await open(tester, size: 8);
    expect(find.bySemanticsLabel(RegExp('^Row ')), findsNWidgets(64));
    await play(tester, [
      for (var c = 0; c < 4; c++) ...[(3, c), (7, c)],
    ]);
    expect(find.text("X's turn"), findsOneWidget);
    await play(tester, [(3, 4)]);
    expect(find.text('X wins!'), findsOneWidget);
  });
}
