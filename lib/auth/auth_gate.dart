import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/game_store.dart';
import '../data/history_screen.dart';
import '../game/setup_screen.dart';
import '../ui/settings_screen.dart';
import '../ui/theme.dart';
import 'profile.dart';
import 'sign_in_screen.dart';
import '../ui/strings.dart';

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
  late final StreamSubscription<User?> _signIns;

  @override
  void initState() {
    super.initState();
    // A guest who signs up or signs in keeps the games they played (REQ-ACC-03).
    _signIns = widget.auth.authStateChanges().listen((user) {
      if (user != null) widget.store.moveGuestGames(user.uid);
    });
  }

  @override
  void dispose() {
    _signIns.cancel();
    super.dispose();
  }

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
          // Guests go back to the sign-in screen to create an account.
          signOutLabel: user == null ? 'Sign up' : 'Sign out',
          onProfile: user == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                      auth: widget.auth,
                      profiles: Profiles(widget.store.firestore),
                      store: widget.store))),
          onSignOut: () async {
            setState(() => _guest = false);
            await widget.auth.signOut();
          },
          onHistory: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  HistoryScreen(store: widget.store, uid: user?.uid))),
          onPlay: (size) => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SetupScreen(
                  initialSize: size, store: widget.store, uid: user?.uid))),
        );
      },
    );
  }
}

/// Home menu. Each board card opens the game setup screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.name,
    this.signOutLabel = 'Sign out',
    this.onProfile,
    required this.onSignOut,
    required this.onHistory,
    required this.onPlay,
  });

  final String name, signOutLabel;
  final VoidCallback? onProfile;
  final VoidCallback onSignOut;
  final VoidCallback onHistory;
  final void Function(int size) onPlay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final classic = _ModeCard(
      title: 'Classic 3×3',
      subtitle: 'Three in a row on the small board.',
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
          IconButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined)),
          if (onProfile != null)
            IconButton(
                onPressed: onProfile,
                tooltip: 'Profile',
                icon: const Icon(Icons.account_circle_outlined)),
          TextButton(
              onPressed: onSignOut, child: Text(context.tr(signOutLabel))),
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
                  child: Text(context.tr('Ready to play?'),
                      style: text.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 4),
                _Reveal(
                    order: 0,
                    child: Text(context.tr('Playing as $name'),
                        style: text.bodyLarge)),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth > 560
                      ? Row(children: [
                          Expanded(child: _Reveal(order: 1, child: classic)),
                          const SizedBox(width: 16),
                          Expanded(child: _Reveal(order: 2, child: big)),
                        ])
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: const Icon(Icons.insights_rounded, size: 32),
                      title: Text(context.tr('History & statistics'),
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle:
                          Text(context.tr('Your games, wins and win rate')),
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
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
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
                Text(context.tr(title),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(context.tr(subtitle),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 15)),
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
        child:
            Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
