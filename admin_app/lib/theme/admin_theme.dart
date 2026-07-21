import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

class AdminTheme {
  static ThemeData get dark => _build(darkMode: true);
  static ThemeData get light => _build(darkMode: false);

  static ThemeData _build({required bool darkMode}) {
    final bg = darkMode ? AppColors.bg : AppColors.bgLight;
    final card = darkMode ? AppColors.card : AppColors.cardLight;
    final inputBg = darkMode ? AppColors.inputBg : AppColors.inputBgLight;
    final text = darkMode ? AppColors.text : AppColors.textLight;
    final textSecondary =
        darkMode ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final borderAlpha = darkMode ? 0.06 : 0.12;

    final base = ThemeData(
      brightness: darkMode ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: darkMode ? Brightness.dark : Brightness.light,
        primary: AppColors.accent,
        onPrimary: Colors.black,
        secondary: AppColors.accent,
        onSecondary: Colors.black,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: card,
        onSurface: text,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: text,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              darkMode ? Brightness.light : Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusLg),
          side: BorderSide(color: Colors.black.withValues(alpha: borderAlpha)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.8)),
        labelStyle: TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: darkMode ? 0.08 : 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.accent : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accent : textSecondary,
            size: 22,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: darkMode ? 0.08 : 0.08),
        thickness: 1,
      ),
    );
  }
}
