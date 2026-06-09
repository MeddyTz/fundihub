import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the app-wide ThemeMode preference.
/// Call [load()] once at startup (before runApp).
class ThemeProvider extends ChangeNotifier {
  static const _key = 'themeMode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode     => _mode;
  bool      get isLight  => _mode == ThemeMode.light;
  bool      get isDark   => _mode == ThemeMode.dark;
  bool      get isSystem => _mode == ThemeMode.system;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _parse(prefs.getString(_key));
    notifyListeners();
  }

  Future<void> setLight()  => _persist(ThemeMode.light);
  Future<void> setDark()   => _persist(ThemeMode.dark);
  Future<void> setSystem() => _persist(ThemeMode.system);

  Future<void> _persist(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _str(m));
  }

  ThemeMode _parse(String? s) {
    if (s == 'light') return ThemeMode.light;
    if (s == 'dark')  return ThemeMode.dark;
    return ThemeMode.system;
  }

  String _str(ThemeMode m) {
    if (m == ThemeMode.light) return 'light';
    if (m == ThemeMode.dark)  return 'dark';
    return 'system';
  }
}
