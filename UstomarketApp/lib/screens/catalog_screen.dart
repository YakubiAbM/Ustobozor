import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/product.dart';
import '../providers/settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../repositories/product_repository.dart';
import '../widgets/product_grid.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Product> _allProducts = [];
  List<String> _brands = [];
  bool _isLoading = true;
  bool _fetchStarted = false;

  /// Выбранный бренд: null = показываем весь каталог (категории), иначе — только товары этого бренда
  String? _selectedBrand;
  List<Product> _productsByBrand = [];
  bool _loadingBrand = false;

  // Навигация внутри каталога
  String? _selectedCategory;
  String? _selectedSubcategory;

  @override
  void initState() {
    super.initState();
    _loadCachedProducts();
    _loadCachedBrands();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureFetch();
    });
  }

  void _ensureFetch() {
    if (_fetchStarted) return;
    _fetchStarted = true;
    _fetchProducts();
    _fetchBrands();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadCachedBrands() async {
    final brands = await ProductRepository.instance.getCachedBrands();
    if (!mounted || brands.isEmpty) return;
    setState(() => _brands = brands);
  }

  Future<void> _fetchBrands() async {
    try {
      final brands = await ProductRepository.instance.refreshBrands();
      if (!mounted || brands.isEmpty) return;
      setState(() => _brands = brands);
    } catch (_) {}
  }

  Future<void> _loadCachedProducts() async {
    final products = await ProductRepository.instance.getCachedAllProducts();
    if (!mounted || products.isEmpty) return;
    setState(() {
      _allProducts = products;
      _isLoading = false;
      if (_brands.isEmpty) {
        _brands =
            products
                .map((p) => p.brand)
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
      }
    });
  }

  Future<void> _fetchProducts() async {
    try {
      final products = await ProductRepository.instance.refreshAllProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _isLoading = false;
        if (_brands.isEmpty) {
          _brands =
              _allProducts
                  .map((p) => p.brand)
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Загрузка товаров по бренду: GET /products?brand=...
  Future<void> _fetchProductsByBrand(String brand) async {
    setState(() {
      _selectedBrand = brand;
      _loadingBrand = true;
      _productsByBrand = [];
    });
    try {
      final cached = await ProductRepository.instance.getCachedProductsByBrand(
        brand,
      );
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _productsByBrand = cached;
          _loadingBrand = false;
        });
      }
      final products = await ProductRepository.instance.refreshProductsByBrand(
        brand,
      );
      if (!mounted) return;
      setState(() {
        _productsByBrand = products;
        _loadingBrand = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBrand = false);
    }
  }

  void _clearBrandFilter() {
    setState(() {
      _selectedBrand = null;
      _productsByBrand = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final inputBg = isDark ? AppColors.inputBg : AppColors.inputBgLight;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 8),
              child: Row(
                children: [
                  Text(
                    'Ustomarket',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      settings.t('search'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (_brands.isNotEmpty)
              _buildBrandChips(context, isDark, theme, onSurface),
            if (_selectedCategory != null && _selectedBrand == null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_selectedSubcategory != null) {
                            _selectedSubcategory = null;
                          } else {
                            _selectedCategory = null;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedSubcategory ?? _selectedCategory!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _selectedBrand != null
                  ? (_loadingBrand
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          )
                        : _buildProductsGrid(context, _productsByBrand))
                  : (_isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          )
                        : _buildContent(
                            context,
                            theme,
                            surfaceColor,
                            onSurface,
                          )),
            ),
          ],
        ),
      ),
    );
  }

  /// Круглые кнопки брендов (как истории в Instagram): GET /brands, по нажатию — GET /products?brand= и показ товаров.
  Widget _buildBrandChips(
    BuildContext context,
    bool isDark,
    ThemeData theme,
    Color onSurface,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'БРЕНДЫ',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            children: [
              _buildBrandCircle(context, 'Все', null, isDark, onSurface),
              const SizedBox(width: 16),
              ..._brands.map(
                (brand) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildBrandCircle(
                    context,
                    brand,
                    brand,
                    isDark,
                    onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBrandCircle(
    BuildContext context,
    String label,
    String? brandValue,
    bool isDark,
    Color onSurface,
  ) {
    final isAll = brandValue == null;
    final selected = isAll
        ? _selectedBrand == null
        : _selectedBrand == brandValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isAll) {
            _clearBrandFilter();
          } else {
            _fetchProductsByBrand(brandValue);
          }
        },
        borderRadius: BorderRadius.circular(44),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : AppColors.accent.withOpacity(0.6),
              width: selected ? 3 : 2,
            ),
            color: selected
                ? AppColors.accent
                : (isDark ? const Color(0xFF374151) : AppColors.inputBgLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label.length > 10 ? '${label.substring(0, 8)}…' : label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.accentContrastText : onSurface,
            ),
          ),
        ),
      ),
    );
  }

  /// Сетка товаров по переданному списку (для фильтра по бренду).
  Widget _buildProductsGrid(BuildContext context, List<Product> products) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'Нет товаров этого бренда',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }
    return ProductGrid(
      products: products,
      padding: const EdgeInsets.all(15),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    Color surfaceColor,
    Color onSurface,
  ) {
    if (_selectedCategory == null) {
      final categories = _allProducts.map((p) => p.category).toSet().toList();
      return _buildGrid(
        categories,
        (cat) => setState(() => _selectedCategory = cat),
        surfaceColor,
        onSurface,
      );
    }

    // 2. Если выбрана категория, но не подкатегория - показываем ПОДКАТЕГОРИИ
    if (_selectedSubcategory == null) {
      final subcats = _allProducts
          .where(
            (p) => p.category == _selectedCategory && p.subcategory.isNotEmpty,
          )
          .map((p) => p.subcategory)
          .toSet()
          .toList();

      // Если подкатегорий нет, сразу показываем товары
      if (subcats.isEmpty) {
        return _buildProductsList(context);
      }

      return ListView(
        padding: const EdgeInsets.all(15),
        children: [
          const Text(
            'Выберите раздел',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...subcats
              .map(
                (sub) => GestureDetector(
                  onTap: () => setState(() => _selectedSubcategory = sub),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: onSurface.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sub,
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          // Кнопка "Показать все"
          GestureDetector(
            onTap: () => setState(
              () => _selectedSubcategory = '',
            ), // Пустая строка как маркер "все"
            child: Container(
              padding: const EdgeInsets.all(15),
              alignment: Alignment.center,
              child: const Text(
                'Показать все товары',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ),
        ],
      );
    }

    return _buildProductsList(context);
  }

  Widget _buildGrid(
    List<String> items,
    Function(String) onTap,
    Color surfaceColor,
    Color onSurface,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        return GestureDetector(
          onTap: () => onTap(items[i]),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: onSurface.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 5),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              items[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsList(BuildContext context) {
    final products = _allProducts.where((p) {
      final catMatch = p.category == _selectedCategory;
      final subMatch =
          (_selectedSubcategory == '' || _selectedSubcategory == null)
          ? true
          : p.subcategory == _selectedSubcategory;
      return catMatch && subMatch;
    }).toList();

    if (products.isEmpty)
      return const Center(
        child: Text('Пусто', style: TextStyle(color: Colors.grey)),
      );

    return ProductGrid(
      products: products,
      padding: const EdgeInsets.all(15),
    );
  }
}
