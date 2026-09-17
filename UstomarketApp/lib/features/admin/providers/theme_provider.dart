import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminThemeProvider with ChangeNotifier {
  static const _key = 'admin_dark_theme';

  bool _isDark = true;
  bool get isDark => _isDark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
  }

  Future<void> toggle() async {
    await setDark(!_isDark);
  }
}
