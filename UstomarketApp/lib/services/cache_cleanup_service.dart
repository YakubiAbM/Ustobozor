import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'api_cache_service.dart';
import 'app_image_cache_manager.dart';

class CacheCleanupService {
  CacheCleanupService._();

  static Future<void> clearAll() async {
    await DefaultCacheManager().emptyCache();
    await AppImageCacheManager.instance.emptyCache();
    await ApiCacheService.instance.clear();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
