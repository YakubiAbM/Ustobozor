import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/product.dart';
import 'admin_auth_api.dart';
import 'admin_http.dart';

class ProductCategories {
  ProductCategories({required this.categories, required this.subcategories});

  final List<String> categories;
  final List<String> subcategories;

  factory ProductCategories.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is! List) return [];
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }

    return ProductCategories(
      categories: parseList(json['categories']),
      subcategories: parseList(json['subcategories']),
    );
  }
}

class AdminProductsApi {
  static const _timeout = Duration(seconds: 20);

  static Uri _u(String path, [Map<String, String>? q]) {
    final uri = Uri.parse('$baseUrl$path');
    return q == null ? uri : uri.replace(queryParameters: q);
  }

  /// Категории и подкатегории из базы (админ API).
  static Future<ProductCategories> fetchCategories() async {
    final res = await AdminHttp.get('/admin/api/products/categories');
    if (res.statusCode != 200) {
      throw Exception('Ошибка категорий: ${res.statusCode}');
    }
    return ProductCategories.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// Список товаров для админа (включая нет в наличии).
  static Future<List<AdminProduct>> fetchAdminProducts({
    String? query,
    String? category,
    int limit = 100,
  }) async {
    final res = await AdminHttp.get(
      '/admin/api/products',
      query: {
        'limit': '$limit',
        'offset': '0',
        if (query != null && query.trim().isNotEmpty) 'search': query.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    if (res.statusCode == 403) {
      throw Exception('Нет доступа к товарам');
    }
    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки товаров: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return [];
    return data
        .map<AdminProduct>(
          (e) => AdminProduct.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// Публичный каталог (fallback).
  static Future<List<AdminProduct>> fetchProducts({String? query, String? category}) async {
    http.Response res;
    if (query != null && query.trim().isNotEmpty) {
      res = await http
          .get(_u('/products/search', {
            'q': query.trim(),
            if (category != null && category.isNotEmpty) 'category': category,
          }))
          .timeout(_timeout);
    } else {
      res = await http
          .get(_u('/products', {
            'limit': '100',
            'offset': '0',
            if (category != null && category.isNotEmpty) 'category': category,
          }))
          .timeout(_timeout);
    }

    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки товаров: ${res.statusCode}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final List<dynamic> rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map && data['items'] is List) {
      rawList = data['items'] as List;
    } else {
      return [];
    }

    return rawList
        .map<AdminProduct>(
          (e) => AdminProduct.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<void> deleteProduct(int productId) async {
    final res = await AdminHttp.delete('/admin/api/products/$productId');
    if (res.statusCode != 200) {
      throw Exception('Не удалось удалить товар');
    }
  }

  static Future<void> deleteProductsBulk(List<int> ids) async {
    final res = await AdminHttp.post(
      '/admin/api/products/delete_bulk',
      body: {'product_ids': ids},
    );
    if (res.statusCode != 200) {
      throw Exception('Не удалось удалить товары');
    }
  }

  static Future<void> setStock(int productId, bool inStock) async {
    final res = await AdminHttp.post(
      '/admin/api/products/$productId/stock',
      body: {'in_stock': inStock},
    );
    if (res.statusCode != 200) {
      throw Exception('Не удалось обновить наличие');
    }
  }

  /// Создание товара через /admin/add_product (multipart-форма).
  static Future<void> createProduct(
    AdminProductDraft p, {
    List<http.MultipartFile> files = const [],
  }) async {
    await AdminAuthApi.ensureAdminSession();

    final req = http.MultipartRequest('POST', _u('/admin/add_product'));

    req.fields['name'] = p.name;
    req.fields['price'] = p.price.toString();
    req.fields['brand'] = p.brand ?? '';

    if (p.newCategory != null && p.newCategory!.isNotEmpty) {
      req.fields['category'] = 'NEW';
      req.fields['new_category'] = p.newCategory!;
    } else {
      req.fields['category'] = p.category ?? '';
      req.fields['new_category'] = '';
    }

    if (p.newSubcategory != null && p.newSubcategory!.isNotEmpty) {
      req.fields['subcategory'] = 'NEW';
      req.fields['new_subcategory'] = p.newSubcategory!;
    } else {
      req.fields['subcategory'] = p.subcategory ?? '';
      req.fields['new_subcategory'] = '';
    }

    req.fields['articul'] = p.articul ?? '';
    req.fields['description'] = p.description ?? '';
    req.fields['unit'] = p.unit ?? 'шт';

    for (final s in p.sizesNames) {
      req.fields['sizes_names'] = s;
    }
    for (final sp in p.sizesPrices) {
      req.fields['sizes_prices'] = sp.toString();
    }
    for (final cn in p.colorsNames) {
      req.fields['colors_names'] = cn;
    }
    for (final cv in p.colorsValues) {
      req.fields['colors_values'] = cv;
    }

    req.files.addAll(files);
    if (AdminAuthApi.cookie != null) {
      req.headers['cookie'] = AdminAuthApi.cookie!;
    }

    final res = await req.send().timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 400) {
      throw Exception('Ошибка создания товара: ${res.statusCode}');
    }
  }

  /// Редактирование товара через /admin/edit_product/{id}
  static Future<void> updateProduct(
    int productId,
    AdminProductDraft p, {
    List<String> existingPhotos = const [],
    List<http.MultipartFile> newFiles = const [],
  }) async {
    await AdminAuthApi.ensureAdminSession();

    final req = http.MultipartRequest('POST', _u('/admin/edit_product/$productId'));

    req.fields['name'] = p.name;
    req.fields['price'] = p.price.toString();
    req.fields['brand'] = p.brand ?? '';

    if (p.newCategory != null && p.newCategory!.isNotEmpty) {
      req.fields['category'] = 'NEW';
      req.fields['new_category'] = p.newCategory!;
    } else {
      req.fields['category'] = p.category ?? '';
      req.fields['new_category'] = '';
    }

    if (p.newSubcategory != null && p.newSubcategory!.isNotEmpty) {
      req.fields['subcategory'] = 'NEW';
      req.fields['new_subcategory'] = p.newSubcategory!;
    } else {
      req.fields['subcategory'] = p.subcategory ?? '';
      req.fields['new_subcategory'] = '';
    }

    req.fields['articul'] = p.articul ?? '';
    req.fields['description'] = p.description ?? '';
    req.fields['unit'] = p.unit ?? 'шт';

    for (final ph in existingPhotos) {
      req.fields['existing_photos'] = ph;
    }

    for (final s in p.sizesNames) {
      req.fields['sizes_names'] = s;
    }
    for (final sp in p.sizesPrices) {
      req.fields['sizes_prices'] = sp.toString();
    }
    for (final cn in p.colorsNames) {
      req.fields['colors_names'] = cn;
    }
    for (final cv in p.colorsValues) {
      req.fields['colors_values'] = cv;
    }

    req.files.addAll(newFiles);

    if (AdminAuthApi.cookie != null) {
      req.headers['cookie'] = AdminAuthApi.cookie!;
    }

    final res = await req.send().timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 400) {
      throw Exception('Ошибка обновления товара: ${res.statusCode}');
    }
  }
}
