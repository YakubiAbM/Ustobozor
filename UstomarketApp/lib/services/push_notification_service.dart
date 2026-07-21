import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../screens/master_notifications_screen.dart';

/// Обработчик FCM, когда приложение в фоне или закрыто. Должен быть top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Если бэкенд шлёт только "data" без "notification", на Android уведомление не покажется.
  // Нужно, чтобы сервер отправлял блок "notification" (title, body) — тогда система сама покажет уведомление.
  if (kDebugMode) {
    debugPrint('FCM background: ${message.notification?.title} ${message.data}');
  }
}

/// Push-уведомления через Firebase Cloud Messaging.
/// Запрос разрешений, получение FCM-токена, отправка токена на бэкенд, открытие экрана уведомлений по тапу.
class PushNotificationService {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static String? _lastFcmToken;

  static String? get lastFcmToken => _lastFcmToken;

  /// Вызвать из main() после Firebase.initializeApp(). Передать navigatorKey от MaterialApp.
  /// Разрешение на уведомления не запрашивается здесь — см. [requestPermissionWhenEnteringApp].
  static Future<void> init(GlobalKey<NavigatorState>? navigatorKey) async {
    _navigatorKey = navigatorKey;

    final messaging = FirebaseMessaging.instance;
    // Токен получим после вызова requestPermissionWhenEnteringApp() при входе в приложение
    final token = await messaging.getToken();
    if (token != null) _lastFcmToken = token;

    messaging.onTokenRefresh.listen((newToken) {
      _lastFcmToken = newToken;
      // Регистрация на бэкенде произойдёт при следующем открытии профиля (если мастер залогинен)
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _openNotificationsScreen());

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openNotificationsScreen());
    }
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Уведомление';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    if (_navigatorKey?.currentContext != null) {
      ScaffoldMessenger.of(_navigatorKey!.currentContext!).showSnackBar(
        SnackBar(
          content: Text((body.isEmpty ? title : '$title\n$body').trim()),
          action: SnackBarAction(
            label: 'Открыть',
            onPressed: () => _openNotificationsScreen(),
          ),
        ),
      );
    }
  }

  static void _openNotificationsScreen() {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MasterNotificationsScreen()),
    );
  }

  /// Запросить разрешение на уведомления при входе в приложение (когда пользователь уже видит экран).
  /// Вызывается из MainLayout при первом показе главного экрана.
  static Future<void> requestPermissionWhenEnteringApp() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final token = await messaging.getToken();
    if (token != null) _lastFcmToken = token;
  }

  /// Вызвать после входа мастера. Регистрирует FCM-токен на бэкенде (POST /notifications/register_token).
  static Future<void> registerTokenIfNeeded(String? masterAccessToken) async {
    final token = _lastFcmToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || masterAccessToken == null || masterAccessToken.isEmpty) return;
    try {
      await apiPostWithBearer(
        '/notifications/register_token',
        masterAccessToken,
        body: {
          'token': token,
          'platform': 'android',
        },
      );
    } catch (_) {}
  }
}
