import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_gate.dart';
import 'data/game_store.dart';
import 'firebase_options.dart';
import 'ui/app_settings.dart';
import 'ui/theme.dart';
import 'ui/tutorial_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // On by default on phones; this also turns on the offline copy on web.
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  final prefs = await SharedPreferences.getInstance();
  runApp(TicTacToeArenaApp(
    auth: FirebaseAuth.instance,
    store: GameStore(firestore: FirebaseFirestore.instance, prefs: prefs),
    settings: AppSettings(prefs),
  ));
}

class TicTacToeArenaApp extends StatelessWidget {
  TicTacToeArenaApp(
      {super.key,
      required this.auth,
      required this.store,
      AppSettings? settings})
      : settings = settings ?? AppSettings();

  final FirebaseAuth auth;
  final GameStore store;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'TicTacToe Arena',
          debugShowCheckedModeBanner: false,
          theme: arenaTheme(Brightness.light),
          darkTheme: arenaTheme(Brightness.dark),
          themeMode: settings.themeMode,
          // Urdu turns the layout right-to-left (REQ-UX-06).
          locale: Locale(settings.urdu ? 'ur' : 'en'),
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => ArenaBackground(child: child!),
          home: settings.tutorialSeen
              ? AuthGate(auth: auth, store: store)
              : TutorialScreen(onDone: () => settings.tutorialSeen = true),
        ),
      ),
    );
  }
}
