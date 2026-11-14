import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_gate.dart';
import 'data/game_store.dart';
import 'firebase_options.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // On by default on phones; this also turns on the offline copy on web.
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  runApp(TicTacToeArenaApp(
    auth: FirebaseAuth.instance,
    store: GameStore(
      firestore: FirebaseFirestore.instance,
      prefs: await SharedPreferences.getInstance(),
    ),
  ));
}

class TicTacToeArenaApp extends StatelessWidget {
  const TicTacToeArenaApp({super.key, required this.auth, required this.store});

  final FirebaseAuth auth;
  final GameStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TicTacToe Arena',
      debugShowCheckedModeBanner: false,
      theme: arenaTheme(Brightness.light),
      darkTheme: arenaTheme(Brightness.dark),
      builder: (context, child) => ArenaBackground(child: child!),
      home: AuthGate(auth: auth, store: store),
    );
  }
}
