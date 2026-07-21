import 'package:flutter/material.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';

/// Единый кэш каталога для Home + Catalog (IndexedStack).
class ProductsProvider with ChangeNotifier {
  final List<Product> _products = [];
  int _total = 0;
  bool _hasMore = true;
  int _offset = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _initialized = false;
  bool _loadingAll = false;

  List<Product> get products => List.unmodifiable(_products);
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isInitialized => _initialized;

  List<String> get categories {
    final cats = _products.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList()
      ..sort();
    return ['all', ...cats];
  }

  List<Product> productsInCategory(String category) {
    if (category == 'all') return products;
    return _products.where((p) => p.category == category).toList();
  }

  Product? findById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> ensureLoaded() async {
    if (_initialized && _products.isNotEmpty) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _offset = 0;
    _hasMore = true;
    _products.clear();
    notifyListeners();
    try {
      final page = await ProductRepository.instance.fetchProductsPage(
        limit: ProductRepository.defaultPageSize,
        offset: 0,
      );
      _products.addAll(page.items);
      _total = page.total;
      _hasMore = page.hasMore;
      _offset = page.items.length;
      _initialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await ProductRepository.instance.fetchProductsPage(
        limit: ProductRepository.defaultPageSize,
        offset: _offset,
      );
      _products.addAll(page.items);
      _total = page.total;
      _hasMore = page.hasMore;
      _offset += page.items.length;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Фоновая подгрузка всех страниц (для каталога с категориями).
  Future<void> loadAllPagesIfNeeded() async {
    if (_loadingAll || !_hasMore) return;
    _loadingAll = true;
    try {
      while (_hasMore) {
        await loadMore();
      }
    } finally {
      _loadingAll = false;
    }
  }
}
