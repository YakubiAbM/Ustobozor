import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../services/push_notification_service.dart';
import '../services/secure_token_storage.dart';
import '../utils/master_code_format.dart';

class MasterAuthProvider with ChangeNotifier {
  static const _keyMasterId = 'master_id';
  static const _keyMasterName = 'master_name';
  static const _keyMasterPhone = 'master_phone';
  static const _keyMasterPoints = 'master_points';
  static const _keyMasterCode = 'master_code';
  static const _keyMasterBarcodeLegacy = 'master_barcode';
  static const _keyMasterDebt = 'master_debt';

  int? _masterId;
  String _masterName = '';
  String _masterPhone = '';
  int _points = 0;
  double _debt = 0;
  String? _masterCode;
  String? _accessToken;

  int? get masterId => _masterId;
  String get masterName => _masterName;
  String get masterPhone => _masterPhone;
  int get points => _points;
  double get debt => _debt;
  String? get masterCode => _effectiveMasterCode;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _masterId != null;
  bool get hasDebt => _debt > 0;

  /// @deprecated Используйте [masterCode]. Оставлено для совместимости.
  String? get barcode => masterCode;

  String? get _effectiveMasterCode {
    final stored = _masterCode;
    if (stored != null && stored.isNotEmpty) return stored;
    if (_masterPhone.isNotEmpty) {
      final fromPhone = masterCodeFromPhone(_masterPhone);
      if (fromPhone.isNotEmpty) return fromPhone;
    }
    if (_masterId != null) return _masterId.toString();
    return null;
  }

  MasterAuthProvider() {
    _load();
  }

  Future<void> _load() async {
    await SecureTokenStorage.migrateFromSharedPreferencesIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    _masterId = prefs.getInt(_keyMasterId);
    _masterName = prefs.getString(_keyMasterName) ?? '';
    _masterPhone = prefs.getString(_keyMasterPhone) ?? '';
    _points = prefs.getInt(_keyMasterPoints) ?? 0;
    _debt = prefs.getDouble(_keyMasterDebt) ?? 0;

    var code = prefs.getString(_keyMasterCode);
    if (code == null || code.isEmpty) {
      final legacy = prefs.getString(_keyMasterBarcodeLegacy);
      if (legacy != null &&
          legacy.isNotEmpty &&
          !isLegacyBarcodeImagePath(legacy)) {
        code = legacy;
      }
    }
    _masterCode =
        (code != null && code.isNotEmpty && !isLegacyBarcodeImagePath(code))
            ? code
            : null;

    _accessToken = await SecureTokenStorage.readAccessToken();
    notifyListeners();
  }

  Future<void> refresh() async => _load();

  Future<void> refreshPointsFromServer() async {
    if (_masterPhone.isEmpty) return;
    try {
      final r =
          await apiGet('/auth/me', queryParameters: {'phone': _masterPhone});
      final body = json.decode(r.body);
      if (body is Map) {
        if (body['points'] != null) {
          final p = body['points'];
          final points = p is int ? p : (p is num ? p.toInt() : 0);
          await setPoints(points);
        }
        if (body['debt'] != null) {
          final d = body['debt'];
          final debtVal =
              d is num ? d.toDouble() : (double.tryParse(d.toString()) ?? 0.0);
          _debt = debtVal >= 0 ? debtVal : 0;
          notifyListeners();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(_keyMasterDebt, _debt);
        }
        await _persistMasterCodeFromBody(body);
      }
    } catch (_) {
      await _load();
    }
  }

  Future<void> _persistMasterCodeFromBody(Map body) async {
    final raw = body['master_code'] ?? body['barcode'];
    if (raw == null) return;
    final code = raw.toString().trim();
    if (code.isEmpty || isLegacyBarcodeImagePath(code)) return;

    _masterCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMasterCode, code);
    await prefs.remove(_keyMasterBarcodeLegacy);
  }

  Future<void> setMaster({
    required int masterId,
    required String name,
    required String phone,
    int points = 0,
    String? masterCode,
    String? barcode,
    String? accessToken,
    String? refreshToken,
  }) async {
    _masterId = masterId;
    _masterName = name;
    _masterPhone = phone;
    _points = points;

    final codeRaw = (masterCode ?? barcode ?? '').trim();
    _masterCode = codeRaw.isNotEmpty && !isLegacyBarcodeImagePath(codeRaw)
        ? codeRaw
        : null;

    _accessToken = (accessToken != null && accessToken.trim().isNotEmpty)
        ? accessToken.trim()
        : null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMasterId, masterId);
    await prefs.setString(_keyMasterName, name);
    await prefs.setString(_keyMasterPhone, phone);
    await prefs.setInt(_keyMasterPoints, points);
    if (_masterCode != null) {
      await prefs.setString(_keyMasterCode, _masterCode!);
      await prefs.remove(_keyMasterBarcodeLegacy);
    } else {
      await prefs.remove(_keyMasterCode);
    }

    await SecureTokenStorage.writeAccessToken(_accessToken);
    await SecureTokenStorage.writeRefreshToken(refreshToken);

    if (_accessToken != null) {
      try {
        await PushNotificationService.registerTokenIfNeeded(_accessToken);
      } catch (_) {}
    }
  }

  Future<void> setPoints(int newBalance) async {
    _points = newBalance;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMasterPoints, newBalance);
  }

  Future<void> logout() async {
    _masterId = null;
    _masterName = '';
    _masterPhone = '';
    _points = 0;
    _debt = 0;
    _masterCode = null;
    _accessToken = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMasterId);
    await prefs.remove(_keyMasterName);
    await prefs.remove(_keyMasterPhone);
    await prefs.remove(_keyMasterPoints);
    await prefs.remove(_keyMasterDebt);
    await prefs.remove(_keyMasterCode);
    await prefs.remove(_keyMasterBarcodeLegacy);
    await SecureTokenStorage.clearAll();
  }
}
