import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JWT и refresh-токены — только в защищённом хранилище ОС (Keychain / Keystore).
class SecureTokenStorage {
  SecureTokenStorage._();

  static const _accessKey = 'master_access_token';
  static const _refreshKey = 'master_refresh_token';
  static const _legacyAccessKey = 'master_access_token';
  static const _clientAccessKey = 'client_access_token';
  static const _clientRefreshKey = 'client_refresh_token';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  static Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  static Future<void> writeAccessToken(String? token) async {
    if (token == null || token.trim().isEmpty) {
      await _storage.delete(key: _accessKey);
      return;
    }
    await _storage.write(key: _accessKey, value: token.trim());
  }

  static Future<void> writeRefreshToken(String? token) async {
    if (token == null || token.trim().isEmpty) {
      await _storage.delete(key: _refreshKey);
      return;
    }
    await _storage.write(key: _refreshKey, value: token.trim());
  }

  static Future<void> clearAll() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _clientAccessKey);
    await _storage.delete(key: _clientRefreshKey);
  }

  static Future<String?> readClientAccessToken() =>
      _storage.read(key: _clientAccessKey);

  static Future<String?> readClientRefreshToken() =>
      _storage.read(key: _clientRefreshKey);

  static Future<void> writeClientAccessToken(String? token) async {
    if (token == null || token.trim().isEmpty) {
      await _storage.delete(key: _clientAccessKey);
      return;
    }
    await _storage.write(key: _clientAccessKey, value: token.trim());
  }

  static Future<void> writeClientRefreshToken(String? token) async {
    if (token == null || token.trim().isEmpty) {
      await _storage.delete(key: _clientRefreshKey);
      return;
    }
    await _storage.write(key: _clientRefreshKey, value: token.trim());
  }

  static Future<void> clearClientTokens() async {
    await _storage.delete(key: _clientAccessKey);
    await _storage.delete(key: _clientRefreshKey);
  }

  /// Однократная миграция с незащищённого SharedPreferences.
  static Future<void> migrateFromSharedPreferencesIfNeeded() async {
    final existing = await readAccessToken();
    if (existing != null && existing.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyAccessKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await writeAccessToken(legacy);
      await prefs.remove(_legacyAccessKey);
    }
  }
}
