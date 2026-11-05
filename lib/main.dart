import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(TicTacToeArenaApp(auth: FirebaseAuth.instance));
}

class TicTacToeArenaApp extends StatelessWidget {
  const TicTacToeArenaApp({super.key, required this.auth});

  final FirebaseAuth auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TicTacToe Arena',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: AuthGate(auth: auth),
    );
  }
}
