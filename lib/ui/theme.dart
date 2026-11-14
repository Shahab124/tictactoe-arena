import 'package:flutter/material.dart';

/// Colours and theme for the whole app, in light and dark mode.
///
/// X and O each get their own colour, and they also differ by shape, so the
/// game never relies on colour alone (D3 5.8).
class ArenaColors {
  static const x = Color(0xFF2F6BFF); // electric blue
  static const o = Color(0xFFFF6A4D); // coral
  static const win = Color(0xFFFFC53D); // gold for the winning line

  static const _lightTop = Color(0xFFEAF1FF);
  static const _lightBottom = Color(0xFFFFF0EB);
  static const _darkTop = Color(0xFF0F1630);
  static const _darkBottom = Color(0xFF231626);

  static LinearGradient background(Brightness b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: b == Brightness.dark
            ? const [_darkTop, _darkBottom]
            : const [_lightTop, _lightBottom],
      );
}

ThemeData arenaTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: ArenaColors.x,
    brightness: brightness,
  );
  const radius = BorderRadius.all(Radius.circular(16));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface.withValues(alpha: 0.85),
      shape: const RoundedRectangleBorder(borderRadius: radius),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: const OutlineInputBorder(borderRadius: radius),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}

/// The soft two-colour background behind every screen.
class ArenaBackground extends StatelessWidget {
  const ArenaBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            gradient: ArenaColors.background(Theme.of(context).brightness)),
        child: child,
      );
}

/// Animation length that drops to zero when the player has turned off
/// animations on their device.
Duration motion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: ms);
