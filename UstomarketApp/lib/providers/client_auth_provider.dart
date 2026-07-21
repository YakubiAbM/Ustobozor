import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/secure_token_storage.dart';

class ClientAuthProvider with ChangeNotifier {
  static const _keyClientId = 'client_id';
  static const _keyClientName = 'client_name';
  static const _keyClientPhone = 'client_phone';

  int? _clientId;
  String _name = '';
  String _phone = '';
  String? _accessToken;

  int? get clientId => _clientId;
  String get clientName => _name;
  String get clientPhone => _phone;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _clientId != null;

  ClientAuthProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getInt(_keyClientId);
    _name = prefs.getString(_keyClientName) ?? '';
    _phone = prefs.getString(_keyClientPhone) ?? '';
    _accessToken = await SecureTokenStorage.readClientAccessToken();
    notifyListeners();
  }

  Future<void> setClient({
    required int clientId,
    required String name,
    required String phone,
    String? accessToken,
    String? refreshToken,
  }) async {
    _clientId = clientId;
    _name = name.trim().isEmpty ? 'Клиент' : name.trim();
    _phone = phone;
    _accessToken = accessToken?.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyClientId, clientId);
    await prefs.setString(_keyClientName, _name);
    await prefs.setString(_keyClientPhone, phone);
    await SecureTokenStorage.writeClientAccessToken(_accessToken);
    await SecureTokenStorage.writeClientRefreshToken(refreshToken);
    notifyListeners();
  }

  Future<void> logout() async {
    _clientId = null;
    _name = '';
    _phone = '';
    _accessToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyClientId);
    await prefs.remove(_keyClientName);
    await prefs.remove(_keyClientPhone);
    await SecureTokenStorage.clearClientTokens();
    notifyListeners();
  }
}
