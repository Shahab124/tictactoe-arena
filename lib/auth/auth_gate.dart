import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'sign_in_screen.dart';

/// Shows the sign-in screen until the player signs in or chooses guest play.
///
/// Firebase keeps the player signed in between app launches, and the same
/// account works on every device (REQ-ACC-04).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});

  final FirebaseAuth auth;

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
        );
      },
    );
  }
}

/// Placeholder home until the game screen (SCRUM-14) is merged.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.name, required this.onSignOut});

  final String name;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TicTacToe Arena'),
        actions: [
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
      body: Center(child: Text('Playing as $name')),
    );
  }
}
