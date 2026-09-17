import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// === КОНФИГУРАЦИЯ СЕРВЕРА ===
/// `true` — ходить на локальный backend (localhost / эмулятор).
/// `false` — prod `https://ustobozor.tj`.
const bool kUseLocalApi = true;

/// Prod API.
const String kProdBaseUrl = 'https://ustobozor.tj';

/// Порт локального uvicorn (`python -m uvicorn main:app --host 0.0.0.0 --port 8000`).
const int kLocalApiPort = 8000;

/// Для физического устройства в одной Wi‑Fi сети с Mac.
/// Узнать IP: `ipconfig getifaddr en0`
const String kLocalLanHost = '172.20.10.14';

/// `true` — использовать LAN IP (реальный телефон). `false` — emulator/simulator.
const bool kUseLanHostForLocalApi = false;

String get baseUrl {
  if (!kUseLocalApi) return kProdBaseUrl;
  if (kUseLanHostForLocalApi) {
    return 'http://$kLocalLanHost:$kLocalApiPort';
  }
  if (kIsWeb) return 'http://127.0.0.1:$kLocalApiPort';
  try {
    if (Platform.isAndroid) {
      // Android emulator → хост-машина.
      return 'http://10.0.2.2:$kLocalApiPort';
    }
    if (Platform.isIOS) {
      // iOS Simulator → localhost.
      return 'http://127.0.0.1:$kLocalApiPort';
    }
  } catch (_) {}
  return 'http://127.0.0.1:$kLocalApiPort';
}

/// Единственный URL для всех API-запросов и картинок.
String get effectiveBaseUrl => baseUrl;

/// Prod: false. Dev: true (нужен SKIP_MASTER_OTP=1 на бэке).
const bool kAllowDevMasterLogin = false;

/// Программа баллов мастеров (временно отключена).
const bool kMasterPointsEnabled = false;

/// QR / штрих-код мастера в профиле (временно отключён).
const bool kMasterBarcodeEnabled = false;

/// Отзывы / рейтинг мастеров (временно отключены).
const bool kMasterReviewsEnabled = true;

/// Папка загрузок на сервере (если путь из API без static/).
const String uploadsPath = 'static/uploads';
const String kAppPlaceholderAssetPath = 'assets/icon (2).png';

// === ЦВЕТА Ustobozor ===
class AppColors {
  // Фоны
  static const Color bg = Color(0xFF06070C);
  static const Color bgLight = Color(0xFFF3F4F6);

  // Карточки
  static const Color cardBg = Color(0xFF1F2937);
  static const Color cardBgLight = Color(0xFFFFFFFF);

  // Текст
  static const Color text = Color(0xFFEEF2FF);
  static const Color textLight = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Поля ввода
  static const Color inputBg = Color(0xFF111827);
  static const Color inputBgLight = Color(0xFFE5E7EB);

  // Бренд
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentContrastText = Color(0xFF000000);
  static const Color orange = Color(0xFFFF6900);

  // Разделители
  static const Color dividerDark = Color(0x1AFFFFFF); // white10
  static const Color dividerLight = Color(0x1F000000); // black12

  // Градиенты баннеров
  static const Color bannerGradientEndDark = Color(0xFF92400E);
  static const Color bannerGradientEndLight = Color(0xFFFDE68A);
  static const Color masterStatsGradientStart = Color(0xFF1F2937);
  static const Color masterStatsGradientEnd = Color(0xFFB45309);

  static Color secondary(bool isDark) =>
      isDark ? textSecondary : textSecondaryLight;

  static Color divider(bool isDark) => isDark ? dividerDark : dividerLight;

  static Color scaffold(bool isDark) => isDark ? bg : bgLight;

  static Color card(bool isDark) => isDark ? cardBg : cardBgLight;

  static Color primaryText(bool isDark) => isDark ? text : textLight;

  static Color inputFill(bool isDark) => isDark ? inputBg : inputBgLight;

  static ButtonStyle accentButtonStyle({
    EdgeInsetsGeometry? padding,
    double borderRadius = 12,
  }) =>
      ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: accentContrastText,
        padding: padding ?? const EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
}

/// Общие отступы и скругления главного экрана.
class AppLayout {
  static const double screenHorizontalPadding = 16.0;
  static const double cardBorderRadius = 16.0;
}

/// Собирает URL фото. Если в БД сохранён 127.0.0.1 — подменяем на baseUrl.
String getImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  final trimmed = path.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.host == '127.0.0.1' || uri.host == 'localhost')) {
      final pathPart = uri.path.isEmpty ? '/' : uri.path;
      final query = uri.query.isEmpty ? '' : '?${uri.query}';
      return '$effectiveBaseUrl$pathPart$query';
    }
    return trimmed;
  }
  if (trimmed.startsWith('/')) return '$effectiveBaseUrl$trimmed';
  if (trimmed.startsWith('static/')) return '$effectiveBaseUrl/$trimmed';
  if (trimmed.startsWith('images/')) {
    return '$effectiveBaseUrl/static/$trimmed';
  }
  // Файлы мастеров/товаров обычно в static/images
  if (trimmed.toLowerCase().endsWith('.webp') ||
      trimmed.toLowerCase().endsWith('.jpg') ||
      trimmed.toLowerCase().endsWith('.jpeg') ||
      trimmed.toLowerCase().endsWith('.png')) {
    return '$effectiveBaseUrl/static/images/$trimmed';
  }
  return '$effectiveBaseUrl/$uploadsPath/$trimmed';
}

/// Показать аккуратное уведомление «Добавлено в корзину».
void showAddedToCartMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(milliseconds: 1500),
      backgroundColor: AppColors.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.accentContrastText,
            size: 22,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.accentContrastText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
