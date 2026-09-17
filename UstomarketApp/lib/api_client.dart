import 'dart:convert';

import 'package:http/http.dart' as http;

import 'constants.dart';
import 'services/api_http_client.dart';
import 'services/api_ready.dart';

const _timeout = Duration(seconds: 60);
const _retries = 2;
const _userAgent = 'UstobozorApp/1.0 (Android)';

void _logApiError(String label, Object e) {
  // ignore: avoid_print
  print('API $label failed: $e');
}

/// Исключение с текстом ответа сервера (4xx).
class ApiClientException implements Exception {
  final String message;
  ApiClientException(this.message);
  @override
  String toString() => message;
}

String _parseErrorMessage(http.Response r, {String fallback = 'Ошибка запроса'}) {
  String msg = fallback;
  try {
    final decoded = jsonDecode(utf8.decode(r.bodyBytes));
    if (decoded is Map) {
      final d = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (d != null) {
        if (d is String) {
          msg = d;
        } else if (d is List && d.isNotEmpty) {
          final first = d.first;
          if (first is Map) {
            final loc = first['loc'];
            final m = first['msg'] ?? first['message'] ?? first.toString();
            msg = (loc is List && loc.isNotEmpty)
                ? '${loc.join(' → ')}: $m'
                : m.toString();
          } else {
            msg = first.toString();
          }
        } else {
          msg = d.toString();
        }
      }
    }
  } catch (_) {
    final raw = utf8.decode(r.bodyBytes);
    if (raw.trim().isNotEmpty) msg = raw;
  }
  if (r.statusCode == 404) {
    msg = 'Не найдено (404). Проверьте адрес сервера.';
  }
  return msg;
}

Future<T> _withRetry<T>(Future<T> Function() action, {required String label}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= _retries; attempt++) {
    try {
      return await action();
    } catch (e) {
      lastError = e;
      if (e is ApiClientException) rethrow;
      if (e is Exception && e.toString().contains('Ошибка запроса')) rethrow;
      _logApiError('retry $attempt/$_retries $label', e);
      if (attempt < _retries) {
        await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
      }
    }
  }
  throw lastError ?? Exception('Сервер недоступен ($effectiveBaseUrl). Проверьте сеть.');
}

http.Client get _http => ApiHttpClient.instance.client;

Map<String, String> _mergeHeaders(Map<String, String>? headers) {
  return {
    'User-Agent': _userAgent,
    'Accept': 'application/json',
    if (headers != null) ...headers,
  };
}

Future<http.Response> apiGet(
  String path, {
  Map<String, String>? queryParameters,
  Map<String, String>? headers,
  Set<int> acceptedStatusCodes = const <int>{},
}) {
  return _withRetry(() async {
    await ApiReady.wait();
    var uri = Uri.parse('$effectiveBaseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final r = await _http.get(uri, headers: _mergeHeaders(headers)).timeout(_timeout);
    if ((r.statusCode >= 200 && r.statusCode < 300) ||
        acceptedStatusCodes.contains(r.statusCode)) {
      // ignore: avoid_print
      print('API OK GET $path -> ${r.statusCode} (${r.bodyBytes.length} bytes)');
      return r;
    }
    if (r.statusCode >= 400 && r.statusCode < 500) {
      throw ApiClientException(_parseErrorMessage(r));
    }
    throw Exception('HTTP ${r.statusCode}');
  }, label: 'GET $path');
}

Future<http.Response> apiPost(String path, {Map<String, dynamic>? body}) {
  return _withRetry(() async {
    await ApiReady.wait();
    final uri = Uri.parse('$effectiveBaseUrl$path');
    final r = await _http
        .post(
          uri,
          headers: _mergeHeaders({'Content-Type': 'application/json'}),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r;
    }
    if (r.statusCode >= 400 && r.statusCode < 500) {
      // Не ретраим клиентские ошибки (409 «уже зарегистрирован» и т.п.).
      throw ApiClientException(_parseErrorMessage(r));
    }
    throw Exception('HTTP ${r.statusCode}');
  }, label: 'POST $path');
}

Future<http.Response> apiGetWithBearer(
  String path,
  String token, {
  Map<String, String>? queryParameters,
}) {
  return _withRetry(() async {
    await ApiReady.wait();
    var uri = Uri.parse('$effectiveBaseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final r = await _http
        .get(
          uri,
          headers: _mergeHeaders({'Authorization': 'Bearer $token'}),
        )
        .timeout(_timeout);
    if (r.statusCode >= 200 && r.statusCode < 300) return r;
    if (r.statusCode >= 400 && r.statusCode < 500) {
      throw ApiClientException(_parseErrorMessage(r));
    }
    throw Exception('HTTP ${r.statusCode}');
  }, label: 'GET $path');
}

Future<http.Response> apiPatchWithBearer(String path, String token) {
  return _withRetry(() async {
    await ApiReady.wait();
    final uri = Uri.parse('$effectiveBaseUrl$path');
    final r = await _http
        .patch(
          uri,
          headers: _mergeHeaders({'Authorization': 'Bearer $token'}),
        )
        .timeout(_timeout);
    if (r.statusCode >= 200 && r.statusCode < 300) return r;
    if (r.statusCode >= 400 && r.statusCode < 500) {
      throw ApiClientException(_parseErrorMessage(r));
    }
    throw Exception('HTTP ${r.statusCode}');
  }, label: 'PATCH $path');
}

Future<http.Response> apiPostWithBearer(
  String path,
  String token, {
  Map<String, dynamic>? body,
  Set<int> acceptedStatusCodes = const <int>{},
}) {
  return _withRetry(() async {
    await ApiReady.wait();
    final uri = Uri.parse('$effectiveBaseUrl$path');
    final r = await _http
        .post(
          uri,
          headers: _mergeHeaders({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          }),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    if ((r.statusCode >= 200 && r.statusCode < 300) ||
        acceptedStatusCodes.contains(r.statusCode)) {
      return r;
    }
    if (r.statusCode >= 400 && r.statusCode < 500) {
      throw ApiClientException(_parseErrorMessage(r));
    }
    throw Exception('HTTP ${r.statusCode}');
  }, label: 'POST $path');
}
