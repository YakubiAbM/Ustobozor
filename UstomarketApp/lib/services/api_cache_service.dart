import 'package:hive/hive.dart';

class ApiCacheEntry {
  const ApiCacheEntry({
    required this.key,
    required this.body,
    required this.updatedAt,
    this.eTag,
  });

  final String key;
  final String body;
  final DateTime updatedAt;
  final String? eTag;

  factory ApiCacheEntry.fromMap(Map<dynamic, dynamic> map) {
    final rawUpdatedAt = map['updatedAt'];
    return ApiCacheEntry(
      key: (map['key'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      updatedAt: rawUpdatedAt is String
          ? DateTime.tryParse(rawUpdatedAt) ??
                DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
      eTag: _normalizeNullableString(map['etag']),
    );
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'body': body,
    'updatedAt': updatedAt.toIso8601String(),
    'etag': eTag,
  };

  static String? _normalizeNullableString(dynamic value) {
    final stringValue = value?.toString().trim() ?? '';
    return stringValue.isEmpty ? null : stringValue;
  }
}

class ApiCacheService {
  ApiCacheService._();

  static const boxName = 'app_api_cache';
  static final ApiCacheService instance = ApiCacheService._();

  Box<dynamic>? _box;

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box(boxName);
      return;
    }
    _box = await Hive.openBox(boxName);
  }

  Future<ApiCacheEntry?> getEntry(String key) async {
    await init();
    final raw = _box!.get(key);
    if (raw is! Map) return null;
    final entry = ApiCacheEntry.fromMap(raw);
    if (entry.body.trim().isEmpty) return null;
    return entry;
  }

  Future<void> saveEntry(String key, String body, {String? eTag}) async {
    await init();
    await _box!.put(
      key,
      ApiCacheEntry(
        key: key,
        body: body,
        updatedAt: DateTime.now(),
        eTag: eTag,
      ).toMap(),
    );
  }

  Future<void> clear() async {
    await init();
    await _box!.clear();
  }
}
