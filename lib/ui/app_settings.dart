import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Board and symbol skins (REQ-UX-05). Each pair stays easy to tell apart.
enum Skin {
  classic('Classic', Color(0xFF2F6BFF), Color(0xFFFF6A4D)),
  neon('Neon', Color(0xFF00BCD4), Color(0xFFE040FB)),
  forest('Forest', Color(0xFF2E7D32), Color(0xFFF57C00));

  const Skin(this.label, this.x, this.o);
  final String label;
  final Color x, o;
}

/// The player's look-and-feel choices, kept on the device: theme, skin,
/// sound and vibration (REQ-UX-03, 04, 05).
class AppSettings extends ChangeNotifier {
  /// With no [prefs], choices last only while the app is open (used in tests).
  AppSettings([this._prefs])
      : _theme = ThemeMode.values[_prefs?.getInt('theme') ?? 0],
        _skin = Skin.values[_prefs?.getInt('skin') ?? 0],
        _sound = _prefs?.getBool('sound') ?? true,
        _vibration = _prefs?.getBool('vibration') ?? true,
        _urdu = _prefs?.getBool('urdu') ?? false,
        _colourBlind = _prefs?.getBool('colourBlind') ?? false,
        // Shown once on a real first launch; never in tests without prefs.
        _tutorialSeen =
            _prefs == null || (_prefs.getBool('tutorialSeen') ?? false);

  final SharedPreferences? _prefs;
  ThemeMode _theme;
  Skin _skin;
  bool _sound, _vibration, _urdu, _colourBlind, _tutorialSeen;

  ThemeMode get themeMode => _theme;
  Skin get skin => _skin;
  bool get sound => _sound;
  bool get vibration => _vibration;

  /// Urdu instead of English (REQ-UX-06).
  bool get urdu => _urdu;

  /// Okabe-Ito blue and orange, which colour-blind players can tell apart,
  /// instead of the skin's colours (REQ-UX-07). X and O also differ by shape.
  bool get colourBlind => _colourBlind;
  bool get tutorialSeen => _tutorialSeen;

  Color get xColor => _colourBlind ? const Color(0xFF0072B2) : _skin.x;
  Color get oColor => _colourBlind ? const Color(0xFFE69F00) : _skin.o;

  set themeMode(ThemeMode v) =>
      _set(() => _theme = v, () => _prefs?.setInt('theme', v.index));
  set skin(Skin v) =>
      _set(() => _skin = v, () => _prefs?.setInt('skin', v.index));
  set sound(bool v) =>
      _set(() => _sound = v, () => _prefs?.setBool('sound', v));
  set vibration(bool v) =>
      _set(() => _vibration = v, () => _prefs?.setBool('vibration', v));
  set urdu(bool v) => _set(() => _urdu = v, () => _prefs?.setBool('urdu', v));
  set colourBlind(bool v) =>
      _set(() => _colourBlind = v, () => _prefs?.setBool('colourBlind', v));
  set tutorialSeen(bool v) =>
      _set(() => _tutorialSeen = v, () => _prefs?.setBool('tutorialSeen', v));

  void _set(void Function() change, void Function() save) {
    change();
    save();
    notifyListeners();
  }

  /// A click and a short buzz for a move; a stronger buzz when a game ends.
  /// Either can be switched off (REQ-UX-04).
  void feedback({bool gameOver = false}) {
    if (_sound) SystemSound.play(SystemSoundType.click);
    if (_vibration) {
      gameOver ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
    }
  }

  static final _fallback = AppSettings();

  /// The app's settings, or defaults when a screen is shown on its own.
  static AppSettings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
          ?.notifier ??
      _fallback;
}

/// Makes [AppSettings] available to every screen and rebuilds them on change.
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope(
      {super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);
}
