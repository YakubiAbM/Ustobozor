import 'package:flutter/material.dart';

import 'constants.dart';

ThemeData buildAppTheme({required bool isDark}) {
  final colorScheme = isDark
      ? const ColorScheme.dark(
          primary: AppColors.accent,
          onPrimary: AppColors.accentContrastText,
          surface: AppColors.cardBg,
          onSurface: AppColors.text,
        )
      : const ColorScheme.light(
          primary: AppColors.accent,
          onPrimary: AppColors.accentContrastText,
          surface: AppColors.cardBgLight,
          onSurface: AppColors.textLight,
        );

  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: AppColors.scaffold(isDark),
    primaryColor: AppColors.accent,
    colorScheme: colorScheme,
    useMaterial3: true,
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.scaffold(isDark),
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.secondary(isDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: AppColors.accentButtonStyle(),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return null;
      }),
      checkColor: const WidgetStatePropertyAll(AppColors.accentContrastText),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return AppColors.secondary(isDark);
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accent.withValues(alpha: 0.35);
        }
        return null;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.accent,
      contentTextStyle: const TextStyle(color: AppColors.accentContrastText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
