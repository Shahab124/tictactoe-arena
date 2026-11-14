import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/game_store.dart';
import '../data/history_screen.dart';
import '../game/game_screen.dart';
import '../ui/theme.dart';
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
    final text = Theme.of(context).textTheme;
    final classic = _ModeCard(
      title: 'Classic 3×3',
      subtitle: 'Three in a row. Two players, one device.',
      icon: Icons.grid_3x3_rounded,
      colors: const [ArenaColors.x, Color(0xFF5C8DFF)],
      onTap: () => onPlay(3),
    );
    final big = _ModeCard(
      title: 'Big 8×8',
      subtitle: 'Five in a row on the large board.',
      icon: Icons.grid_4x4_rounded,
      colors: const [ArenaColors.o, Color(0xFFFF9472)],
      onTap: () => onPlay(8),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('TicTacToe Arena',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Reveal(
                  order: 0,
                  child: Text('Ready to play?',
                      style: text.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 4),
                _Reveal(order: 0, child: Text('Playing as $name', style: text.bodyLarge)),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth > 560
                      ? Row(children: [
                          Expanded(child: _Reveal(order: 1, child: classic)),
                          const SizedBox(width: 16),
                          Expanded(child: _Reveal(order: 2, child: big)),
                        ])
                      : Column(children: [
                          _Reveal(order: 1, child: classic),
                          const SizedBox(height: 16),
                          _Reveal(order: 2, child: big),
                        ]),
                ),
                const SizedBox(height: 16),
                _Reveal(
                  order: 3,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: const Icon(Icons.insights_rounded, size: 32),
                      title: const Text('History & statistics',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Your games, wins and win rate'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: onHistory,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A colourful card that starts a game mode.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 40),
                const SizedBox(height: 28),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92), fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts its child in, one after another by [order].
class _Reveal extends StatelessWidget {
  const _Reveal({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = order * 0.15;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion(context, 450 + order * 120),
      curve: Interval(start / (1 + start), 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
