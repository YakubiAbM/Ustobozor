import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppUserMode { client, master }

/// Активный режим UI: Заказчик / Мастер (без повторного входа).
class AppModeProvider with ChangeNotifier {
  AppUserMode _mode = AppUserMode.client;
  bool _loaded = false;

  AppUserMode get mode => _mode;
  bool get isMasterMode => _mode == AppUserMode.master;
  bool get isClientMode => _mode == AppUserMode.client;
  bool get loaded => _loaded;

  AppModeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('app_user_mode') ?? 'client';
    _mode = raw == 'master' ? AppUserMode.master : AppUserMode.client;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AppUserMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'app_user_mode',
      mode == AppUserMode.master ? 'master' : 'client',
    );
    notifyListeners();
  }

  Future<void> switchToClient() => setMode(AppUserMode.client);
  Future<void> switchToMaster() => setMode(AppUserMode.master);
}
