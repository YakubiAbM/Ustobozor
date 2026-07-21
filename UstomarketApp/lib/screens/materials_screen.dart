import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/product.dart';
import '../widgets/product_grid.dart';
import '../providers/settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../repositories/product_repository.dart';
import '../services/api_cache_service.dart';
import '../utils/app_page_route.dart';
import 'catalog_screen.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  static bool _initialLoadDone = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = ['all'];
  bool _isLoading = true;
  String _activeCategory = 'all';
  String _searchQuery = '';

  Timer? _debounce;
  bool _isSearchingRemote = false;
  int _searchRequestSeq = 0;

  static const _debounceMs = 350;
  static const _searchLimit = 40;

  @override
  void initState() {
    super.initState();
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    nav.addListener(_onNavChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoadDone) {
      _initialLoadDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Provider.of<NavigationProvider>(
          context,
          listen: false,
        ).setHomeDataLoadedOnce(true);
      });
      _loadCachedProducts();
      _fetchProducts(showError: true);
    }
  }

  void _onNavChanged() {
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    if (!nav.requestHomeRefresh || !mounted) return;
    nav.clearRequestHomeRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshData();
    });
  }

  Future<void> _refreshData() async {
    await ApiCacheService.instance.clear();
    await _fetchProducts(showError: true);
  }

  @override
  void dispose() {
    Provider.of<NavigationProvider>(
      context,
      listen: false,
    ).removeListener(_onNavChanged);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCachedProducts() async {
    final products = await ProductRepository.instance.getCachedAllProducts();
    if (!mounted || products.isEmpty) return;
    setState(() {
      _allProducts = products;
      _categories = [
        'all',
        ...products.map((p) => p.category).toSet().toList(),
      ];
      _applyFilterCatalog();
      _isLoading = false;
    });
  }

  Future<void> _fetchProducts({bool showError = false}) async {
    try {
      final list = await ProductRepository.instance.refreshAllProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = list;
        _categories = ['all', ...list.map((p) => p.category).toSet().toList()];
        _applyFilterCatalog();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Нет связи с сервером ($effectiveBaseUrl). Потяните вниз для повтора.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _applyFilterCatalog() {
    _filteredProducts = _allProducts
        .where((p) => _activeCategory == 'all' || p.category == _activeCategory)
        .toList();
  }

  Future<void> _searchProductsRemote(String query) async {
    final q = query.trim();
    if (q.length < 2) return;

    _searchRequestSeq++;
    final seq = _searchRequestSeq;

    if (!mounted) return;
    setState(() => _isSearchingRemote = true);

    try {
      final list = await ProductRepository.instance.searchProducts(
        query: q,
        category: _activeCategory,
        limit: _searchLimit,
        offset: 0,
      );
      if (!mounted || seq != _searchRequestSeq) return;
      setState(() {
        _filteredProducts = list;
        _isSearchingRemote = false;
      });
    } catch (_) {
      if (!mounted || seq != _searchRequestSeq) return;
      setState(() {
        _filteredProducts = [];
        _isSearchingRemote = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _searchQuery = val;

    if (val.trim().isEmpty) {
      setState(() {
        _isSearchingRemote = false;
        _applyFilterCatalog();
      });
      return;
    }

    if (val.trim().length < 2) {
      setState(() {
        _filteredProducts = [];
        _isSearchingRemote = false;
      });
      return;
    }

    setState(() {});
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      _searchProductsRemote(val.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _isSearchingRemote = false;
      _applyFilterCatalog();
    });
  }

  void _onCategoryTap(String cat) {
    setState(() => _activeCategory = cat);
    if (_searchQuery.trim().isEmpty) {
      _applyFilterCatalog();
      setState(() {});
    } else if (_searchQuery.trim().length >= 2) {
      _searchProductsRemote(_searchQuery.trim());
    } else {
      setState(() => _filteredProducts = []);
    }
  }

  void _openProduct(Product product) {
    _searchFocusNode.unfocus();
    context.read<NavigationProvider>().showProductDetail(product);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      body: GestureDetector(
        onTap: () => _searchFocusNode.unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              RepaintBoundary(
                child: _HomeHeader(
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  isSearching: isSearching,
                  isDark: isDark,
                  onSearchChanged: _onSearchChanged,
                  onClearSearch: _clearSearch,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: AppColors.accent,
                  child: CustomScrollView(
                    cacheExtent: 400,
                    slivers: [
                      if (!isSearching) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppLayout.screenHorizontalPadding,
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 4),
                                _CatalogBanner(isDark: isDark),
                                const SizedBox(height: 20),
                                Text(
                                  'ПОПУЛЯРНЫЕ ТОВАРЫ',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _CategoryChipsRow(
                                  categories: _categories,
                                  activeCategory: _activeCategory,
                                  isLoading: _isLoading,
                                  isSearchingRemote: _isSearchingRemote,
                                  onCategoryTap: _onCategoryTap,
                                ),
                                const SizedBox(height: 15),
                              ],
                            ),
                          ),
                        ),
                      ] else
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppLayout.screenHorizontalPadding,
                              0,
                              AppLayout.screenHorizontalPadding,
                              10,
                            ),
                            child: Text(
                              '${settings.t('search_results')}:',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (_isLoading || _isSearchingRemote)
                        _SkeletonGridSliver(isDark: isDark)
                      else if (_filteredProducts.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: Center(
                              child: Text(
                                isSearching && _searchQuery.trim().length < 2
                                    ? settings.t('search_min_chars')
                                    : settings.t('empty_search'),
                                style: TextStyle(
                                  color: isDark ? Colors.grey : Colors.black45,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppLayout.screenHorizontalPadding,
                            0,
                            AppLayout.screenHorizontalPadding,
                            80,
                          ),
                          sliver: ProductGridSliver(
                            products: _filteredProducts,
                            onProductTap: _openProduct,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.searchController,
    required this.searchFocusNode,
    required this.isSearching,
    required this.isDark,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isSearching;
  final bool isDark;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsProvider>(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenHorizontalPadding,
        12,
        AppLayout.screenHorizontalPadding,
        14,
      ),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                settings.t('materials'),
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: onSearchChanged,
            onSubmitted: (_) => searchFocusNode.unfocus(),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Поиск...',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 22,
              ),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: onClearSearch,
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.inputBg : AppColors.inputBgLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({
    required this.categories,
    required this.activeCategory,
    required this.isLoading,
    required this.isSearchingRemote,
    required this.onCategoryTap,
  });

  final List<String> categories;
  final String activeCategory;
  final bool isLoading;
  final bool isSearchingRemote;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isActive = activeCategory == cat;
          final label = cat == 'all' ? 'Все' : cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isActive ? AppColors.accent : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  if (!isLoading && !isSearchingRemote) {
                    onCategoryTap(cat);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.accentContrastText
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SkeletonGridSliver extends StatelessWidget {
  const _SkeletonGridSliver({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.cardBg : AppColors.cardBgLight;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.screenHorizontalPadding,
        0,
        AppLayout.screenHorizontalPadding,
        80,
      ),
      sliver: SliverGrid(
        gridDelegate: ProductGrid.gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (_, __) => Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }
}

class _CatalogBanner extends StatelessWidget {
  const _CatalogBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final base = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final gradientEnd = isDark
        ? AppColors.bannerGradientEndDark
        : AppColors.bannerGradientEndLight;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            AppPageRoute.deferred((_) => const CatalogScreen()),
          );
        },
        borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, base, gradientEnd],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.accent,
                radius: 28,
                child: Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.accentContrastText,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('catalog_banner_title'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.t('catalog_banner_subtitle'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  settings.t('catalog'),
                  style: const TextStyle(
                    color: AppColors.accentContrastText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
