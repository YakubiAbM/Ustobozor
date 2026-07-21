import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// HTTP-клиент для API. На Android — Cronet (тот же стек, что у Chrome).
class ApiHttpClient {
  ApiHttpClient._();

  static final ApiHttpClient instance = ApiHttpClient._();

  http.Client? _client;
  CronetEngine? _cronetEngine;

  Future<void> init() async {
    if (_client != null) return;

    if (!kIsWeb && Platform.isAndroid) {
      _cronetEngine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 4 * 1024 * 1024,
      );
      _client = CronetClient.fromCronetEngine(_cronetEngine!);
      return;
    }

    _client = IOClient(
      HttpClient()
        ..connectionTimeout = const Duration(seconds: 45)
        ..idleTimeout = const Duration(seconds: 45),
    );
  }

  http.Client get client {
    final c = _client;
    if (c == null) {
      throw StateError('ApiHttpClient.init() must be called before API requests');
    }
    return c;
  }

  Future<void> dispose() async {
    _client?.close();
    _client = null;
    _cronetEngine?.close();
    _cronetEngine = null;
  }
}
