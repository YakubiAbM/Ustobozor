import 'dart:convert';

import '../api_client.dart';
import '../models/product.dart';
import '../services/api_cache_service.dart';

class ProductRepository {
  ProductRepository._();

  static final ProductRepository instance = ProductRepository._();

  static const _productsAllKey = 'products_all';
  static const _brandsAllKey = 'brands_all';

  Future<List<Product>> getCachedAllProducts() async {
    final entry = await ApiCacheService.instance.getEntry(_productsAllKey);
    if (entry == null) return [];
    return _decodeProducts(entry.body);
  }

  Future<List<Product>> refreshAllProducts() async {
    return _fetchProductsWithCache(cacheKey: _productsAllKey);
  }

  Future<List<String>> getCachedBrands() async {
    final entry = await ApiCacheService.instance.getEntry(_brandsAllKey);
    if (entry == null) return [];
    return _decodeBrands(entry.body);
  }

  Future<List<String>> refreshBrands() async {
    return _fetchBrandsWithCache(cacheKey: _brandsAllKey);
  }

  Future<List<Product>> getCachedProductsByBrand(String brand) async {
    final entry = await ApiCacheService.instance.getEntry(_brandKey(brand));
    if (entry == null) return [];
    return _decodeProducts(entry.body);
  }

  Future<List<Product>> refreshProductsByBrand(String brand) async {
    return _fetchProductsWithCache(
      cacheKey: _brandKey(brand),
      queryParameters: {'brand': brand},
    );
  }

  Future<List<Product>> searchProducts({
    required String query,
    String? category,
    int limit = 40,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'q': query.trim(),
      'limit': '$limit',
      'offset': '$offset',
    };
    if (category != null && category.isNotEmpty && category != 'all') {
      params['category'] = category;
    }

    final cacheKey = _searchKey(
      query: query,
      category: category,
      limit: limit,
      offset: offset,
    );
    final cachedEntry = await ApiCacheService.instance.getEntry(cacheKey);
    final shouldCache = _shouldCacheSearchPage(limit: limit, offset: offset);
    final headers = <String, String>{};
    if (shouldCache && cachedEntry?.eTag != null) {
      headers['If-None-Match'] = cachedEntry!.eTag!;
    }

    try {
      final response = await apiGet(
        '/products/search',
        queryParameters: params,
        headers: headers.isEmpty ? null : headers,
        acceptedStatusCodes: shouldCache ? {304} : const <int>{},
      );
      if (response.statusCode == 304 && cachedEntry != null) {
        return _decodeProducts(cachedEntry.body);
      }

      final body = utf8.decode(response.bodyBytes);
      if (shouldCache) {
        await ApiCacheService.instance.saveEntry(
          cacheKey,
          body,
          eTag: _readEtag(response.headers),
        );
      }
      return _decodeProducts(body);
    } catch (_) {
      if (cachedEntry != null) {
        return _decodeProducts(cachedEntry.body);
      }
      rethrow;
    }
  }

  Future<Product?> getProductById(String productId) async {
    var products = await getCachedAllProducts();
    if (products.isEmpty) {
      products = await refreshAllProducts();
    }
    for (final product in products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<List<Product>> getSimilarProducts(Product product) async {
    var products = await getCachedAllProducts();
    if (products.isEmpty) {
      products = await refreshAllProducts();
    }
    return products.where((candidate) {
      if (candidate.id == product.id) return false;
      return candidate.category == product.category &&
          candidate.subcategory == product.subcategory;
    }).toList();
  }

  Future<List<Product>> _fetchProductsWithCache({
    required String cacheKey,
    Map<String, String>? queryParameters,
  }) async {
    final cachedEntry = await ApiCacheService.instance.getEntry(cacheKey);

    try {
      final result = await _fetchAllProducts(queryParameters: queryParameters);
      if (result.cacheBody.isNotEmpty) {
        await ApiCacheService.instance.saveEntry(
          cacheKey,
          result.cacheBody,
          eTag: result.eTag,
        );
      }
      return result.products;
    } catch (_) {
      if (cachedEntry != null) {
        return _decodeProducts(cachedEntry.body);
      }
      rethrow;
    }
  }

  Future<({List<Product> products, String cacheBody, String? eTag})>
      _fetchAllProducts({
    Map<String, String>? queryParameters,
  }) async {
    const pageSize = 100;
    var offset = 0;
    final mergedItems = <Map<String, dynamic>>[];
    String? eTag;

    while (true) {
      final params = <String, String>{
        ...?queryParameters,
        'limit': '$pageSize',
        'offset': '$offset',
      };
      final response = await apiGet('/products', queryParameters: params);
      eTag ??= _readEtag(response.headers);
      final body = utf8.decode(response.bodyBytes);
      final data = json.decode(body);

      if (data is List) {
        return (products: _decodeProducts(body), cacheBody: body, eTag: eTag);
      }

      if (data is Map) {
        final items = data['items'] ?? data['products'] ?? data['data'];
        if (items is! List) {
          break;
        }
        for (final item in items) {
          if (item is Map) {
            mergedItems.add(Map<String, dynamic>.from(item));
          }
        }
        final hasMore = data['has_more'] == true;
        if (!hasMore || items.isEmpty) {
          break;
        }
        offset += pageSize;
        continue;
      }
      break;
    }

    final products = mergedItems
        .map((item) => Product.fromJson(item))
        .toList();
    final cacheBody =
        mergedItems.isEmpty ? '[]' : json.encode(mergedItems);
    return (products: products, cacheBody: cacheBody, eTag: eTag);
  }

  Future<List<String>> _fetchBrandsWithCache({required String cacheKey}) async {
    final cachedEntry = await ApiCacheService.instance.getEntry(cacheKey);
    final headers = <String, String>{};
    if (cachedEntry?.eTag != null) {
      headers['If-None-Match'] = cachedEntry!.eTag!;
    }

    try {
      final response = await apiGet(
        '/brands',
        headers: headers.isEmpty ? null : headers,
        acceptedStatusCodes: const {304},
      );
      if (response.statusCode == 304 && cachedEntry != null) {
        return _decodeBrands(cachedEntry.body);
      }

      final body = utf8.decode(response.bodyBytes);
      await ApiCacheService.instance.saveEntry(
        cacheKey,
        body,
        eTag: _readEtag(response.headers),
      );
      return _decodeBrands(body);
    } catch (_) {
      if (cachedEntry != null) {
        return _decodeBrands(cachedEntry.body);
      }
      rethrow;
    }
  }

  List<Product> _decodeProducts(String body) {
    final dynamic data = json.decode(body);
    final List<dynamic> rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map) {
      final items = data['items'] ?? data['products'] ?? data['data'];
      if (items is! List) return [];
      rawList = items;
    } else {
      return [];
    }
    return rawList
        .whereType<Map>()
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<String> _decodeBrands(String body) {
    final dynamic data = json.decode(body);
    if (data is! List) return [];
    return data
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _brandKey(String brand) =>
      'products_brand_${_normalizeKeyPart(brand)}';

  String _searchKey({
    required String query,
    String? category,
    required int limit,
    required int offset,
  }) {
    final normalizedCategory = category == null || category.isEmpty
        ? 'all'
        : _normalizeKeyPart(category);
    return 'products_search_${_normalizeKeyPart(query)}_${normalizedCategory}_${limit}_$offset';
  }

  String _normalizeKeyPart(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  bool _shouldCacheSearchPage({required int limit, required int offset}) {
    if (limit <= 0) return false;
    final pageIndex = offset ~/ limit;
    return pageIndex < 3;
  }

  String? _readEtag(Map<String, String> headers) {
    final value = headers['etag'] ?? headers['ETag'];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
