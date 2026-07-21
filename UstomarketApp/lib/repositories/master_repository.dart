import 'dart:convert';

import '../api_client.dart';
import '../models/master.dart';
import '../services/api_cache_service.dart';

class MasterRepository {
  MasterRepository._();

  static final MasterRepository instance = MasterRepository._();
  static const _mastersAllKey = 'masters_all';

  Future<List<Master>> getCachedAllMasters() async {
    final entry = await ApiCacheService.instance.getEntry(_mastersAllKey);
    if (entry == null) return [];
    return _decodeMasters(entry.body);
  }

  Future<List<Master>> refreshAllMasters() async {
    final cachedEntry = await ApiCacheService.instance.getEntry(_mastersAllKey);
    final headers = <String, String>{};
    if (cachedEntry?.eTag != null) {
      headers['If-None-Match'] = cachedEntry!.eTag!;
    }

    try {
      final response = await apiGet(
        '/masters',
        headers: headers.isEmpty ? null : headers,
        acceptedStatusCodes: const {304},
      );
      if (response.statusCode == 304 && cachedEntry != null) {
        return _decodeMasters(cachedEntry.body);
      }

      final body = utf8.decode(response.bodyBytes);
      await ApiCacheService.instance.saveEntry(
        _mastersAllKey,
        body,
        eTag: _readEtag(response.headers),
      );
      return _decodeMasters(body);
    } catch (_) {
      if (cachedEntry != null) {
        return _decodeMasters(cachedEntry.body);
      }
      rethrow;
    }
  }

  List<Master> _decodeMasters(String body) {
    final dynamic data = json.decode(body);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => Master.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String? _readEtag(Map<String, String> headers) {
    final value = headers['etag'] ?? headers['ETag'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
