import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../features/admin/api/admin_auth_api.dart';
import '../features/admin/constants.dart' show baseUrl;
import '../features/admin/screens/admin_home_page.dart';

/// Если номер — админский, сервер вернёт шаг PIN (нужен экран пароля, не регистрация).
Future<bool> isAdminPhone(String phone) async {
  try {
    final uri = Uri.parse('$baseUrl/admin/login/check_phone');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone.trim()}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return false;
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is Map && (body['step']?.toString() ?? '') == 'pin') {
      return true;
    }
  } catch (_) {}
  return false;
}

/// Пробует вход в админку. При успехе открывает панель и возвращает true.
Future<bool> tryEnterAdminPanel(
  BuildContext context, {
  required String phone,
  required String password,
}) async {
  final pwd = password.trim();
  if (pwd.isEmpty) return false;
  try {
    await AdminAuthApi.login(phone, pwd);
  } catch (_) {
    return false;
  }
  if (!context.mounted) return true;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AdminHomePage()),
    (route) => route.isFirst,
  );
  return true;
}
