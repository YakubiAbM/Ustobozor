import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageCacheManager {
  AppImageCacheManager._();

  static const _cacheKey = 'ustomarket_media_cache';

  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );
}
