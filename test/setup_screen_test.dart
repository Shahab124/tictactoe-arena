import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/game/game_screen.dart';
import 'package:tictactoe_arena/game/setup_screen.dart';

Future<GameStore> newStore() async {
  SharedPreferences.setMockInitialValues({});
  return GameStore(
      firestore: FakeFirebaseFirestore(),
      prefs: await SharedPreferences.getInstance());
}

/// Sets the screen size in logical pixels.
void screen(WidgetTester tester, double width, double height) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
}

Finder cell(int r, int c) =>
    find.bySemanticsLabel(RegExp('^Row ${r + 1}, column ${c + 1},'));

final cells = find.bySemanticsLabel(RegExp('^Row '));

void main() {
  testWidgets('player picks the board size and starts a two-player game',
      (tester) async {
    screen(tester, 360, 640);
    await tester.pumpWidget(MaterialApp(home: SetupScreen(store: await newStore())));
    expect(find.text('Three in a row wins.'), findsOneWidget);

    await tester.tap(find.text('Big 8×8'));
    await tester.pump();
    expect(find.text('Five in a row wins. Pinch the board to zoom.'), findsOneWidget);

    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    expect(cells, findsNWidgets(64));
    expect(find.text("X's turn"), findsOneWidget);
  });

  testWidgets('starts 3×3 by default and offers both modes', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SetupScreen(store: await newStore())));
    expect(find.text('Two players'), findsOneWidget);
    expect(find.text('Computer'), findsOneWidget);

    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    expect(cells, findsNWidgets(9));
  });

  testWidgets('8×8 board zooms with a pinch, scrolls with a drag, and still takes taps',
      (tester) async {
    screen(tester, 360, 640);
    await tester.pumpWidget(
        MaterialApp(home: GameScreen(size: 8, store: await newStore())));
    final before = tester.getRect(cell(0, 0));

    final centre = tester.getCenter(find.byType(InteractiveViewer));
    final a = await tester.startGesture(centre - const Offset(20, 0), pointer: 1);
    final b = await tester.startGesture(centre + const Offset(20, 0), pointer: 2);
    for (var i = 0; i < 5; i++) {
      await a.moveBy(const Offset(-12, 0));
      await b.moveBy(const Offset(12, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    final zoomed = tester.getRect(cell(0, 0));
    expect(zoomed.width, greaterThan(before.width * 1.5));

    await tester.dragFrom(centre, const Offset(-80, -80));
    await tester.pumpAndSettle();
    final moved = tester.getRect(cell(0, 0));
    expect(moved.left, lessThan(zoomed.left));
    expect(moved.top, lessThan(zoomed.top));

    await tester.tap(cell(4, 4));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Row 5, column 5, X'), findsOneWidget);
  });

  testWidgets('3×3 board has no zoom', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: GameScreen(size: 3, store: await newStore())));
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  // A layout that doesn't fit throws an overflow error, which fails the test.
  for (final (name, width, height) in const [
    ('small phone', 320.0, 568.0),
    ('phone', 412.0, 915.0),
    ('phone landscape', 640.0, 360.0),
    ('tablet', 800.0, 1280.0),
    ('tablet landscape', 1280.0, 800.0),
  ]) {
    testWidgets('setup and 8×8 game fit a $name', (tester) async {
      screen(tester, width, height);
      await tester.pumpWidget(
          MaterialApp(home: SetupScreen(initialSize: 8, store: await newStore())));
      await tester.ensureVisible(find.text('Start game'));
      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();

      final board = tester.getRect(find.byType(InteractiveViewer));
      expect(board.width, closeTo(board.height, 0.5));
      expect(board.left, greaterThanOrEqualTo(0));
      expect(board.right, lessThanOrEqualTo(width));
      expect(board.bottom, lessThanOrEqualTo(height));
      // Big enough to tap: at least half of the shorter side.
      expect(board.width, greaterThan((width < height ? width : height) * 0.5));
      expect(find.text('Restart').hitTestable(), findsOneWidget);

      // Landscape puts the controls beside the board, not under it.
      final status = tester.getRect(find.text("X's turn"));
      if (width > height) {
        expect(status.left, greaterThan(board.right));
      } else {
        expect(status.bottom, lessThanOrEqualTo(board.top));
      }
    });
  }
}
