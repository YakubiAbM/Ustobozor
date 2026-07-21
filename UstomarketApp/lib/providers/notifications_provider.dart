import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_client.dart';

/// Хранит количество непрочитанных уведомлений мастера (для бейджа в профиле).
class NotificationsProvider with ChangeNotifier {
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  /// Запросить GET /notifications/unread_count с Bearer токеном.
  Future<void> refreshUnreadCount(String? token) async {
    if (token == null || token.isEmpty) {
      _unreadCount = 0;
      notifyListeners();
      return;
    }
    try {
      final r = await apiGetWithBearer('/notifications/unread_count', token);
      final body = json.decode(utf8.decode(r.bodyBytes));
      final count = body is Map && body['count'] != null
          ? (body['count'] is int ? body['count'] as int : (body['count'] as num).toInt())
          : 0;
      _unreadCount = count;
      notifyListeners();
    } catch (_) {
      _unreadCount = 0;
      notifyListeners();
    }
  }

  void setUnreadCount(int count) {
    if (_unreadCount != count) {
      _unreadCount = count;
      notifyListeners();
    }
  }
}
