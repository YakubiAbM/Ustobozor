import 'package:flutter/material.dart';

/// `true` — локальный backend. `false` — prod.
const bool kUseLocalApi = true;
const String kProdBaseUrl = 'https://ustobozor.tj';
const String kLocalBaseUrl = 'http://127.0.0.1:8000';

/// Тот же сервер, что и клиентское приложение.
String get baseUrl => kUseLocalApi ? kLocalBaseUrl : kProdBaseUrl;

const String kAppIconAsset = 'assets/icon.png';
const String kSplashAsset = 'assets/splash.png';

/// Программа баллов мастеров (временно отключена).
const bool kMasterPointsEnabled = false;

class AppColors {
  static const Color bg = Color(0xFF06070C);
  static const Color card = Color(0xFF111827);
  static const Color cardElevated = Color(0xFF1F2937);
  static const Color inputBg = Color(0xFF1A202C);
  static const Color accent = Color(0xFF22C55E);
  static const Color orange = Color(0xFFFF6900);
  static const Color text = Color(0xFFEEF2FF);
  static const Color textSecondary = Color(0xFF9CA3AF);

  static const Color bgLight = Color(0xFFF5F5F7);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardElevatedLight = Color(0xFFF3F4F6);
  static const Color inputBgLight = Color(0xFFF3F4F6);
  static const Color textLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);
}

class AppLayout {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double screenPadding = 16;
}

String buildImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  final trimmed = path.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('/')) return '$baseUrl$trimmed';
  if (trimmed.startsWith('static/')) return '$baseUrl/$trimmed';
  return '$baseUrl/static/uploads/$trimmed';
}
