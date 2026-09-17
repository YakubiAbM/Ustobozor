import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'constants.dart';
import 'app_theme.dart';
import 'features/projects/services/project_storage_service.dart';
import 'services/api_cache_service.dart';
import 'services/api_http_client.dart';
import 'services/api_ready.dart';
import 'services/push_notification_service.dart';
import 'providers/cart_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_order_provider.dart';
import 'providers/master_auth_provider.dart';
import 'providers/client_auth_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/app_mode_provider.dart';

import 'screens/main_layout.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

bool get _firebaseSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> _initFirebaseIfSupported() async {
  if (!_firebaseSupported) return;
  try {
    await Firebase.initializeApp();
    await PushNotificationService.init(navigatorKey);
  } catch (e, st) {
    debugPrint('Firebase skipped on this platform: $e\n$st');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebaseIfSupported();
  await initializeDateFormatting('ru');
  await ProjectStorageService.instance.init();
  await ApiCacheService.instance.init();
  await ApiHttpClient.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatOrderProvider()),
        ChangeNotifierProvider(create: (_) => MasterAuthProvider()),
        ChangeNotifierProvider(create: (_) => ClientAuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
      ],
      child:
          Selector<
            SettingsProvider,
            ({bool isDarkMode, String materialLocaleCode})
          >(
            selector: (_, s) => (
              isDarkMode: s.isDarkMode,
              materialLocaleCode: s.materialLocaleCode,
            ),
            builder: (context, settingsState, _) {
              final isDarkMode = settingsState.isDarkMode;
              SystemChrome.setSystemUIOverlayStyle(
                SystemUiOverlayStyle(
                  statusBarColor: isDarkMode ? AppColors.bg : AppColors.bgLight,
                  statusBarIconBrightness: isDarkMode
                      ? Brightness.light
                      : Brightness.dark,
                ),
              );
              return MaterialApp(
                navigatorKey: navigatorKey,
                scaffoldMessengerKey: scaffoldMessengerKey,
                title: 'Ustomarket',
                debugShowCheckedModeBanner: false,
                themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
                locale: Locale(settingsState.materialLocaleCode),
                supportedLocales: const [Locale('ru'), Locale('en')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],

                darkTheme: buildAppTheme(isDark: true),
                theme: buildAppTheme(isDark: false),

                home: const ApiLifecycleGate(child: MainLayout()),
              );
            },
          ),
    );
  }
}
