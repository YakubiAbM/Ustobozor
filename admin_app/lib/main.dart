import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/admin_session.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/admin_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final _themeProvider = AdminThemeProvider();
  bool _showSplash = true;
  bool _authorized = false;
  AdminSession? _session;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    final dark = _themeProvider.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
    );
    setState(() {});
  }

  void _onSplashFinished() {
    setState(() => _showSplash = false);
  }

  void _onAuthorized(AdminSession session) {
    setState(() {
      _authorized = true;
      _session = session;
    });
  }

  void _onLogout() {
    setState(() {
      _authorized = false;
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ustomarket Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light,
      darkTheme: AdminTheme.dark,
      themeMode: _themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: _showSplash
          ? AdminSplashScreen(onFinished: _onSplashFinished)
          : _authorized && _session != null
              ? ShellScreen(
                  session: _session!,
                  onLogout: _onLogout,
                  themeProvider: _themeProvider,
                )
              : LoginScreen(
                  onSuccess: _onAuthorized,
                  themeProvider: _themeProvider,
                ),
    );
  }
}
