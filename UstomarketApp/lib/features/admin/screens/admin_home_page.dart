import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/settings_provider.dart';
import '../api/admin_auth_api.dart';
import '../models/admin_session.dart';
import '../providers/theme_provider.dart';
import '../theme/admin_theme.dart';
import 'login_screen.dart';
import 'shell_screen.dart';

/// Точка входа в админку внутри основного приложения.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final AdminThemeProvider _theme = AdminThemeProvider();
  AdminSession? _session;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _theme.addListener(_onTheme);
    _bootstrap();
  }

  void _onTheme() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await _theme.load();
    // Синхронизируем тему с основным приложением
    if (!mounted) return;
    final isDark = context.read<SettingsProvider>().isDarkMode;
    if (_theme.isDark != isDark) {
      await _theme.setDark(isDark);
    }
    if (AdminAuthApi.isLoggedIn) {
      try {
        _session = await AdminAuthApi.fetchMe();
      } catch (_) {
        AdminAuthApi.logout();
        _session = null;
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _theme.removeListener(_onTheme);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Theme(
      data: _theme.isDark ? AdminTheme.dark : AdminTheme.light,
      child: _session == null
          ? LoginScreen(
              themeProvider: _theme,
              onSuccess: (s) => setState(() => _session = s),
            )
          : ShellScreen(
              session: _session!,
              themeProvider: _theme,
              onLogout: () {
                AdminAuthApi.logout();
                setState(() => _session = null);
              },
            ),
    );
  }
}
