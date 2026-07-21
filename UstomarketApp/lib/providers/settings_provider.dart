import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/translations.dart';

class SettingsProvider with ChangeNotifier {
  String _langCode = 'ru';
  bool _isDarkMode = true;

  String get langCode => _langCode;
  String get materialLocaleCode => _langCode == 'tj' ? 'ru' : _langCode;
  String get intlLocaleCode => _langCode == 'tj' ? 'ru' : _langCode;
  bool get isDarkMode => _isDarkMode;

  SettingsProvider() {
    _loadSettings();
  }

  // Получить перевод
  String t(String key) {
    return Translations.get(_langCode, key);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('lang') ?? 'ru';
    _langCode = savedLang == 'tg' ? 'tj' : savedLang;
    _isDarkMode = prefs.getBool('isDark') ?? true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _langCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', code);
    notifyListeners(); // Обновляет все экраны!
  }

  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    notifyListeners(); // Обновляет все экраны!
  }
}
