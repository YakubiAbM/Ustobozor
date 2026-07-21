import 'dart:convert';

import '../models/master.dart';
import '../models/product.dart';

class ProductsPageResult {
  final List<Product> items;
  final int total;
  final bool hasMore;

  const ProductsPageResult({
    required this.items,
    required this.total,
    required this.hasMore,
  });
}

List<Product> parseProductsList(String body) {
  final dynamic data = json.decode(body);
  final List<dynamic> rawItems;
  if (data is Map<String, dynamic>) {
    final items = data['items'];
    rawItems = items is List ? items : const [];
  } else if (data is List) {
    rawItems = data;
  } else {
    return const [];
  }
  return rawItems
      .whereType<Map>()
      .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

ProductsPageResult parseProductsPage(String body) {
  final dynamic data = json.decode(body);
  if (data is Map<String, dynamic>) {
    final items = parseProductsList(body);
    final total = (data['total'] as num?)?.toInt() ?? items.length;
    final hasMore = data['has_more'] == true;
    return ProductsPageResult(items: items, total: total, hasMore: hasMore);
  }
  final items = parseProductsList(body);
  return ProductsPageResult(
    items: items,
    total: items.length,
    hasMore: false,
  );
}

Product? parseSingleProduct(String body) {
  final dynamic data = json.decode(body);
  if (data is Map<String, dynamic>) {
    return Product.fromJson(data);
  }
  return null;
}

List<Master> parseMastersList(String body) {
  final dynamic data = json.decode(body);
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) => Master.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

List<String> parseBrandsList(String body) {
  final dynamic data = json.decode(body);
  if (data is! List) return const [];
  return data
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
