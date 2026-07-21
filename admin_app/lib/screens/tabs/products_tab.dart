import 'dart:async';
import 'package:flutter/material.dart';

import '../../api/admin_products_api.dart';
import '../../constants.dart';
import '../../models/product.dart';
import '../../widgets/admin_section_header.dart';
import '../../widgets/category_picker_field.dart';
import '../product_detail_screen.dart';
import '../product_edit_screen.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _categories = ['Все'];
  int _selectedCategoryIndex = 0;

  List<AdminProduct> _products = [];
  bool _loading = false;
  String? _error;
  Timer? _searchDebounce;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final meta = await AdminProductsApi.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = ['Все', ...meta.categories];
      });
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadProducts(query: value.trim().length >= 2 ? value : null);
    });
  }

  Future<void> _loadProducts({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final category = _selectedCategoryIndex == 0 ? null : _categories[_selectedCategoryIndex];
      final items = await AdminProductsApi.fetchAdminProducts(
        query: query,
        category: category,
      );
      setState(() {
        _products = items;
        _selectedIds.removeWhere((id) => !items.any((p) => p.id == id));
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalStock => _products.length;

  double get _totalStockValue => _products.fold(0, (sum, p) => sum + p.price);

  Future<void> _openCreateProduct() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductEditScreen()),
    );
    if (changed == true) {
      await _loadCategories();
      _loadProducts(query: _searchController.text);
    }
  }

  Future<void> _openEditProduct(AdminProduct product) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductEditScreen(product: product)),
    );
    if (changed == true) {
      await _loadCategories();
      _loadProducts(query: _searchController.text);
    }
  }

  Future<void> _deleteProduct(AdminProduct product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Удалить товар?', style: TextStyle(color: AppColors.text)),
        content: Text(
          '«${product.name}» будет удалён без возможности восстановления.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminProductsApi.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Товар удалён'), backgroundColor: AppColors.accent),
      );
      _loadProducts(query: _searchController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Удалить выбранные?', style: TextStyle(color: AppColors.text)),
        content: Text(
          'Будет удалено товаров: ${_selectedIds.length}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminProductsApi.deleteProductsBulk(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      _loadProducts(query: _searchController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleStock(AdminProduct product) async {
    try {
      await AdminProductsApi.setStock(product.id, !product.inStock);
      if (!mounted) return;
      _loadProducts(query: _searchController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AdminSectionHeader(
              title: _selectionMode ? 'Выбрано: ${_selectedIds.length}' : 'Товары',
              trailing: _selectionMode
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Удалить',
                          onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        ),
                        IconButton(
                          tooltip: 'Отмена',
                          onPressed: () => setState(() {
                            _selectionMode = false;
                            _selectedIds.clear();
                          }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Поиск товара или кода',
                        filled: true,
                        fillColor: AppColors.inputBg,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Выбрать несколько',
                    onPressed: () => setState(() => _selectionMode = true),
                    icon: const Icon(Icons.checklist),
                  ),
                ],
              ),
            ),
            CategoryFilterChips(
              categories: _categories,
              selectedIndex: _selectedCategoryIndex,
              onSelected: (i) {
                setState(() => _selectedCategoryIndex = i);
                _loadProducts(query: _searchController.text);
              },
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: () async {
                        await _loadCategories();
                        await _loadProducts(query: _searchController.text);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final product = _products[i];
                          final selected = _selectedIds.contains(product.id);
                          return _ProductCard(
                            product: product,
                            selectionMode: _selectionMode,
                            selected: selected,
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelection(product.id);
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    product: product,
                                    onEdit: () => _openEditProduct(product),
                                    onDelete: () => _deleteProduct(product),
                                    onToggleStock: () => _toggleStock(product),
                                  ),
                                ),
                              );
                            },
                            onLongPress: () {
                              setState(() {
                                _selectionMode = true;
                                _selectedIds.add(product.id);
                              });
                            },
                            onEdit: () => _openEditProduct(product),
                            onDelete: () => _deleteProduct(product),
                            onToggleStock: () => _toggleStock(product),
                          );
                        },
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Товаров: $_totalStock',
                            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Сумма цен: ${_totalStockValue.toStringAsFixed(0)} TJS',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _openCreateProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Новый товар', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStock,
    this.selectionMode = false,
    this.selected = false,
    this.onLongPress,
  });

  final AdminProduct product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStock;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.cardElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        side: BorderSide(
          color: selected ? AppColors.accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.inputBg,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (product.image != null && product.image!.isNotEmpty)
                      ? Image.network(
                          buildImageUrl(product.image),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.inbox_outlined, color: AppColors.textSecondary),
                        )
                      : const Icon(Icons.inbox_outlined, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        color: product.inStock ? AppColors.text : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        decoration: product.inStock ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Категория: ${product.category ?? 'Без категории'}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    Text(
                      'Цена: ${product.price.toStringAsFixed(0)} TJS',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    if (!product.inStock)
                      const Text(
                        'Нет в наличии',
                        style: TextStyle(color: AppColors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              if (!selectionMode)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value == 'stock') onToggleStock();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'edit', child: const Text('Редактировать')),
                    PopupMenuItem(
                      value: 'stock',
                      child: Text(product.inStock ? 'Снять с продажи' : 'Вернуть в наличие'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
