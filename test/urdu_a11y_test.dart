import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/game/game_screen.dart';
import 'package:tictactoe_arena/game/setup_screen.dart';
import 'package:tictactoe_arena/main.dart';
import 'package:tictactoe_arena/ui/app_settings.dart';
import 'package:tictactoe_arena/ui/settings_screen.dart';
import 'package:tictactoe_arena/ui/strings.dart';
import 'package:tictactoe_arena/ui/tutorial_screen.dart';

Future<GameStore> store() async {
  SharedPreferences.setMockInitialValues({});
  return GameStore(
      firestore: FakeFirebaseFirestore(),
      prefs: await SharedPreferences.getInstance());
}

void main() {
  test('Urdu covers fixed text and sentences with names in them', () {
    expect(toUrdu('Sign in'), 'سائن ان');
    expect(toUrdu("X's turn"), 'X کی باری');
    expect(toUrdu('You win!'), 'آپ جیت گئے!');
    expect(toUrdu('Computer wins the match!'), 'Computer میچ جیت گیا!');
    expect(toUrdu('Playing as Guest'), 'Guest کے طور پر کھیل رہے ہیں');
    expect(toUrdu('Some new text'), 'Some new text'); // Falls back to English.
  });

  testWidgets('switching to Urdu translates the app and turns it right-to-left',
      (tester) async {
    final settings = AppSettings();
    await tester.pumpWidget(TicTacToeArenaApp(
        auth: MockFirebaseAuth(), store: await store(), settings: settings));
    await tester.pump();
    expect(find.text('Sign in'), findsOneWidget);

    settings.urdu = true;
    await tester.pumpAndSettle();
    expect(find.text('سائن ان'), findsOneWidget);
    expect(find.text('مہمان کے طور پر کھیلیں'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('سائن ان'))),
        TextDirection.rtl);
  });

  testWidgets('the game screen speaks Urdu too', (tester) async {
    final settings = AppSettings()..urdu = true;
    await tester.pumpWidget(AppSettingsScope(
      settings: settings,
      child: MaterialApp(home: GameScreen(size: 3, store: await store())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('X کی باری'), findsOneWidget);
  });

  testWidgets('setup win rules and 8×8 options are translated to Urdu',
      (tester) async {
    final settings = AppSettings()..urdu = true;
    await tester.pumpWidget(AppSettingsScope(
      settings: settings,
      child: MaterialApp(home: SetupScreen(store: await store())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('لگاتار تین نشان جیت دلاتے ہیں۔'), findsOneWidget);

    await tester.tap(find.text('بڑا 8×8'));
    await tester.pump();
    expect(
      find.text('لگاتار پانچ نشان جیت دلاتے ہیں۔ بورڈ بڑا کرنے کے لیے چٹکی لیں۔'),
      findsOneWidget,
    );
    expect(find.text('لگاتار پانچ'), findsOneWidget);

    await tester.tap(find.text('لگاتار چار'));
    await tester.pump();
    expect(
      find.text('لگاتار چار نشان جیت دلاتے ہیں۔ بورڈ بڑا کرنے کے لیے چٹکی لیں۔'),
      findsOneWidget,
    );
    expect(find.text('4 in a row'), findsNothing);
    expect(find.text('5 in a row'), findsNothing);
  });

  test('colour-blind mode swaps to blue and orange for every skin', () {
    final s = AppSettings()..skin = Skin.neon;
    expect(s.xColor, Skin.neon.x);
    s.colourBlind = true;
    expect(s.xColor, const Color(0xFF0072B2));
    expect(s.oColor, const Color(0xFFE69F00));
  });

  testWidgets('every board cell has a screen-reader label', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: GameScreen(size: 3, store: await store())));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Row \d, column \d, (X|O|empty)$')),
        findsNWidgets(9));
  });

  testWidgets('settings switch language and colour-blind mode', (tester) async {
    final s = AppSettings();
    await tester.pumpWidget(AppSettingsScope(
        settings: s, child: const MaterialApp(home: SettingsScreen())));
    await tester.scrollUntilVisible(
        find.text('Colour-blind friendly colours'), 200);
    await tester.tap(find.text('Colour-blind friendly colours'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('اردو'), 200);
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    expect(s.colourBlind, isTrue);
    expect(s.urdu, isTrue);
  });

  testWidgets('first launch shows the tutorial once, then the sign-in screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    await tester.pumpWidget(TicTacToeArenaApp(
        auth: MockFirebaseAuth(),
        store: GameStore(firestore: FakeFirebaseFirestore(), prefs: prefs),
        settings: settings));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialScreen), findsOneWidget);
    expect(find.text('Welcome to TicTacToe Arena'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Five in a row wins on 8×8'), findsNothing);
    expect(find.text('Play your way'), findsOneWidget);
    await tester.tap(find.text("Let's play"));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(AppSettings(prefs).tutorialSeen, isTrue); // Not shown again.
  });
}
