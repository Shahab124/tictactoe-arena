import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/game_store.dart';
import '../data/history_screen.dart';
import '../game/game_screen.dart';
import 'sign_in_screen.dart';

/// Shows the sign-in screen until the player signs in or chooses guest play.
///
/// Firebase keeps the player signed in between app launches, and the same
/// account works on every device (REQ-ACC-04).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, required this.store});

  final FirebaseAuth auth;
  final GameStore store;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Guests have no Firebase account; their games stay on the device (D3, REQ-DATA 1.1b).
  bool _guest = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null && !_guest) {
          return SignInScreen(
            auth: widget.auth,
            onGuest: () => setState(() => _guest = true),
          );
        }
        return HomeScreen(
          name: user?.email ?? user?.displayName ?? 'Guest',
          onSignOut: () async {
            setState(() => _guest = false);
            await widget.auth.signOut();
          },
          onHistory: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  HistoryScreen(store: widget.store, uid: user?.uid))),
          onPlay: (size) => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GameScreen(
                  size: size, store: widget.store, uid: user?.uid))),
        );
      },
    );
  }
}

/// Home menu. The full game setup screen comes in SCRUM-17.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.name,
    required this.onSignOut,
    required this.onHistory,
    required this.onPlay,
  });

  final String name;
  final VoidCallback onSignOut;
  final VoidCallback onHistory;
  final void Function(int size) onPlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TicTacToe Arena'),
        actions: [
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Playing as $name'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => onPlay(3),
              child: const Text('Two players · 3×3'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => onPlay(8),
              child: const Text('Two players · 8×8'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onHistory,
              child: const Text('History & statistics'),
            ),
          ],
        ),
      ),
    );
  }
}
