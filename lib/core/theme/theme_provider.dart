import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the user's chosen theme (Light / Dark / System) and
/// persists the choice so it's remembered across app restarts.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';

  // Changed default from .light to .system so it follows device theme by default
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    switch (saved) {
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'system':
      default:
        // Defaulting to system mode for new installs
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.dark:
        await prefs.setString(_prefsKey, 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString(_prefsKey, 'system');
        break;
      case ThemeMode.light:
        await prefs.setString(_prefsKey, 'light');
        break;
    }
  }
}
