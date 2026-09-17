import 'package:flutter/material.dart';

import '../../constants.dart' as app;

/// Базовый URL API — тот же, что у клиентского приложения.
String get baseUrl => app.effectiveBaseUrl;

const String kAppIconAsset = 'assets/icon (2).png';
const String kSplashAsset = 'assets/icon (2).png';

const bool kMasterPointsEnabled = app.kMasterPointsEnabled;

/// Фирменные цвета Ustomarket (янтарь) — как в основном приложении.
class AppColors {
  static const Color bg = app.AppColors.bg;
  static const Color card = app.AppColors.cardBg;
  static const Color cardElevated = Color(0xFF374151);
  static const Color inputBg = app.AppColors.inputBg;
  static const Color accent = app.AppColors.accent;
  static const Color orange = app.AppColors.orange;
  static const Color text = app.AppColors.text;
  static const Color textSecondary = app.AppColors.textSecondary;

  static const Color bgLight = app.AppColors.bgLight;
  static const Color cardLight = app.AppColors.cardBgLight;
  static const Color cardElevatedLight = Color(0xFFF3F4F6);
  static const Color inputBgLight = app.AppColors.inputBgLight;
  static const Color textLight = app.AppColors.textLight;
  static const Color textSecondaryLight = app.AppColors.textSecondaryLight;
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
