import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/admin_session.dart';

class AdminAuthApi {
  static const _timeout = Duration(seconds: 15);
  static String? _cookie;
  static AdminSession? _session;

  static String? get cookie => _cookie;
  static AdminSession? get session => _session;
  static bool get isLoggedIn => _cookie != null && _cookie!.isNotEmpty;

  static Map<String, String> authHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{
      if (_cookie != null) 'Cookie': _cookie!,
      ...?extra,
    };
    return headers;
  }

  static Future<void> login(String login, String password) async {
    final uri = Uri.parse('$baseUrl/admin/login');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'login': login.trim(),
            'password': password,
          }),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw Exception('Неверный логин или пароль');
    }

    final setCookie = res.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) {
      throw Exception('Сервер не вернул сессию');
    }
    _cookie = setCookie.split(';').first;
    _session = await fetchMe();
  }

  static Future<AdminSession> fetchMe() async {
    await ensureAdminSession();
    final uri = Uri.parse('$baseUrl/admin/api/me');
    final res = await http
        .get(uri, headers: authHeaders())
        .timeout(_timeout);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('Сессия истекла. Войдите снова.');
    }
    if (res.statusCode != 200) {
      throw Exception('Ошибка профиля: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _session = AdminSession.fromJson(data);
    return _session!;
  }

  static Future<void> ensureAdminSession() async {
    if (!isLoggedIn) {
      throw Exception('Требуется вход в систему');
    }
  }

  static void logout() {
    _cookie = null;
    _session = null;
  }
}
