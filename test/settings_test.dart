import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tictactoe_arena/data/game_store.dart';
import 'package:tictactoe_arena/main.dart';
import 'package:tictactoe_arena/ui/app_settings.dart';
import 'package:tictactoe_arena/ui/settings_screen.dart';

void main() {
  test('choices are saved on the device and come back next launch', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    AppSettings(prefs)
      ..themeMode = ThemeMode.dark
      ..skin = Skin.neon
      ..sound = false
      ..vibration = false;

    final again = AppSettings(prefs);
    expect(again.themeMode, ThemeMode.dark);
    expect(again.skin, Skin.neon);
    expect(again.sound, isFalse);
    expect(again.vibration, isFalse);
  });

  test('defaults: system theme, classic skin, sound and vibration on', () {
    final s = AppSettings();
    expect([s.themeMode, s.skin, s.sound, s.vibration],
        [ThemeMode.system, Skin.classic, true, true]);
  });

  test('every skin keeps X and O clearly different', () {
    for (final skin in Skin.values) {
      expect(skin.x, isNot(skin.o));
    }
    expect(Skin.values.length, greaterThanOrEqualTo(2));
  });

  testWidgets('sound and vibration each switch off independently', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    final s = AppSettings();
    s.feedback();
    expect(calls, containsAll(['SystemSound.play', 'HapticFeedback.vibrate']));

    calls.clear();
    s.sound = false;
    s.feedback(gameOver: true);
    expect(calls, ['HapticFeedback.vibrate']);

    calls.clear();
    s.vibration = false;
    s.feedback();
    expect(calls, isEmpty);
  });

  testWidgets('settings screen changes theme, skin and toggles', (tester) async {
    final s = AppSettings();
    await tester.pumpWidget(AppSettingsScope(
        settings: s, child: const MaterialApp(home: SettingsScreen())));
    await tester.tap(find.text('Dark'));
    await tester.tap(find.text('Forest'));
    await tester.tap(find.text('Sound'));
    await tester.pumpAndSettle();
    expect([s.themeMode, s.skin, s.sound], [ThemeMode.dark, Skin.forest, false]);
  });

  testWidgets('the app follows the chosen theme straight away', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = AppSettings();
    await tester.pumpWidget(TicTacToeArenaApp(
      auth: MockFirebaseAuth(),
      store: GameStore(
          firestore: FakeFirebaseFirestore(),
          prefs: await SharedPreferences.getInstance()),
      settings: s,
    ));
    MaterialApp app() => tester.widget(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.system);
    s.themeMode = ThemeMode.dark;
    await tester.pump();
    expect(app().themeMode, ThemeMode.dark);
  });
}
