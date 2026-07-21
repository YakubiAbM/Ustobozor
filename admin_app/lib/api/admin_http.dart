import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'admin_auth_api.dart';

class AdminHttp {
  static const timeout = Duration(seconds: 20);

  static Map<String, String> headers({Map<String, String>? extra}) {
    return AdminAuthApi.authHeaders(extra: extra);
  }

  static Future<http.Response> get(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return http.get(uri, headers: headers()).timeout(timeout);
  }

  static Future<http.Response> post(String path, {Object? body}) {
    final uri = Uri.parse('$baseUrl$path');
    return http
        .post(
          uri,
          headers: headers(extra: {'Content-Type': 'application/json'}),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(timeout);
  }

  static Future<http.Response> delete(String path) {
    final uri = Uri.parse('$baseUrl$path');
    return http.delete(uri, headers: headers()).timeout(timeout);
  }

  static Future<http.Response> put(String path, {Object? body}) {
    final uri = Uri.parse('$baseUrl$path');
    return http
        .put(
          uri,
          headers: headers(extra: {'Content-Type': 'application/json'}),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(timeout);
  }
}
