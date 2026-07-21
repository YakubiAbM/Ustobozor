import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../repositories/product_repository.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/product_card.dart';
import '../utils/app_page_route.dart';
import '../utils/deferred_screen_body.dart';
import 'full_screen_gallery_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final VoidCallback? onBack;

  const ProductDetailScreen({super.key, required this.product, this.onBack});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  int _currentImageIndex = 0;
  ProductSize? _selectedSize;
  ProductColor? _selectedColor;
  late double _currentPrice;
  late PageController _imagePageController;
  List<Product> _similarProducts = [];
  bool _similarLoading = true;

  bool _contentReady = false;

  @override
  void initState() {
    super.initState();
    _syncStateFromProduct(widget.product);
    _imagePageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentReady = true);
      _fetchSimilarProducts();
    });
  }

  @override
  void didUpdateWidget(ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _syncStateFromProduct(widget.product);
      _currentImageIndex = 0;
      _qty = 1;
      setState(() {
        _similarProducts = [];
        _similarLoading = true;
      });
      _imagePageController.jumpToPage(0);
      _fetchSimilarProducts();
    }
  }

  void _syncStateFromProduct(Product product) {
    _currentPrice = product.price;
    _selectedSize = product.sizes.isNotEmpty ? product.sizes.first : null;
    if (_selectedSize != null) _currentPrice = _selectedSize!.price;
    _selectedColor = product.colors.isNotEmpty ? product.colors.first : null;
  }

  Future<void> _fetchSimilarProducts() async {
    final product = widget.product;
    try {
      final all = await ProductRepository.instance.getCachedAllProducts();
      final source = all.isNotEmpty
          ? all
          : await ProductRepository.instance.refreshAllProducts();
      if (!mounted) return;
      setState(() {
        _similarProducts = source.where((p) {
          if (p.id == product.id) return false;
          final sameCategory = p.category == product.category;
          final sameSub = p.subcategory == product.subcategory;
          return sameCategory && sameSub;
        }).toList();
        _similarLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _similarLoading = false);
    }
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  void _selectSize(ProductSize size) {
    setState(() {
      if (_selectedSize == size) {
        _selectedSize = null;
        _currentPrice = widget.product.price;
      } else {
        _selectedSize = size;
        _currentPrice = size.price;
      }
    });
  }

  void _selectColor(ProductColor color) {
    setState(() {
      _selectedColor = _selectedColor == color ? null : color;
    });
  }

  String _cartItemName(Product product) {
    final parts = <String>[product.name];
    if (_selectedSize != null) parts.add(_selectedSize!.name);
    if (_selectedColor != null) parts.add(_selectedColor!.name);
    if (parts.length == 1) return product.name;
    return '${parts[0]} (${parts.sublist(1).join(', ')})';
  }

  String _cartKey(Product product) {
    return '${product.id}_${_cartItemName(product)}';
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final product = widget.product;
    final images = product.photos.isNotEmpty ? product.photos : [''];
    final scaffoldBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final backBtnBg = isDark ? Colors.white : Colors.grey.shade200;
    final backBtnIcon = isDark ? Colors.black : const Color(0xFF111827);
    final sizeChipBg = isDark ? const Color(0xFF374151) : Colors.grey.shade200;
    final colorBorder = isDark ? Colors.white54 : Colors.grey.shade400;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: DeferredScreenBody(
        waitForRouteAnimation: false,
        placeholder: ColoredBox(
          color: scaffoldBg,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: backBtnIcon),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
        ),
        builder: (context) => _contentReady
            ? _buildBody(
                context,
                settings,
                isDark,
                product,
                images,
                scaffoldBg,
                textPrimary,
                textSecondary,
                backBtnBg,
                backBtnIcon,
                sizeChipBg,
                colorBorder,
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SettingsProvider settings,
    bool isDark,
    Product product,
    List<String> images,
    Color scaffoldBg,
    Color textPrimary,
    Color textSecondary,
    Color backBtnBg,
    Color backBtnIcon,
    Color sizeChipBg,
    Color colorBorder,
  ) {
    return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Область с фото
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.78,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          color: isDark ? const Color(0xFF1F2937) : Colors.grey.shade100,
                          child:
                              images.isEmpty ||
                                  (images.length == 1 && images[0].isEmpty)
                              ? Center(
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey.shade400,
                                    size: 80,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    final urls = product.photos
                                        .where((e) => e.isNotEmpty)
                                        .toList();
                                    if (urls.isEmpty) return;
                                    Navigator.push(
                                      context,
                                      AppPageRoute.deferred(
                                        (_) => FullScreenGalleryScreen(
                                          imageUrls: urls,
                                          initialIndex: _currentImageIndex,
                                        ),
                                      ),
                                    );
                                  },
                                  child: PageView.builder(
                                    controller: _imagePageController,
                                    itemCount: images.length,
                                    onPageChanged: (i) =>
                                        setState(() => _currentImageIndex = i),
                                    itemBuilder: (context, i) {
                                      final url = images[i];
                                      if (url.isEmpty) {
                                        return Center(
                                          child: Icon(
                                            Icons.image,
                                            color: Colors.grey.shade400,
                                            size: 80,
                                          ),
                                        );
                                      }
                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          final dpr =
                                              MediaQuery.devicePixelRatioOf(
                                                context,
                                              );
                                          final cacheSide =
                                              (MediaQuery.sizeOf(context).width *
                                                      dpr)
                                                  .round()
                                                  .clamp(1, 1400);
                                          return AppCachedImage(
                                            imagePath: url,
                                            fit: BoxFit.contain,
                                            memCacheWidth: cacheSide,
                                            maxMemCacheSide: 1400,
                                            fallbackIcon: Icons.broken_image,
                                            backgroundColor: isDark
                                                ? const Color(0xFF1F2937)
                                                : Colors.grey.shade100,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                        ),
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          left: 12,
                          child: GestureDetector(
                            onTap: () {
                              if (widget.onBack != null) {
                                widget.onBack!();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                            child: CircleAvatar(
                              backgroundColor: backBtnBg,
                              radius: 22,
                              child: Icon(
                                Icons.arrow_back,
                                color: backBtnIcon,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        if (images.any((e) => e.isNotEmpty))
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_currentImageIndex + 1}/${images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Контентная панель
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: BoxDecoration(
                      color: scaffoldBg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_currentPrice.toInt()} смн',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        if (product.colors.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Цвет:',
                            style: TextStyle(fontSize: 14, color: textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: product.colors.map((c) {
                              final isSelected = _selectedColor == c;
                              return GestureDetector(
                                onTap: () => _selectColor(c),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _parseColor(c.hex),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accent
                                          : colorBorder,
                                      width: isSelected ? 3 : 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.accent
                                                  .withOpacity(0.5),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (product.sizes.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Размер / Вес:',
                            style: TextStyle(fontSize: 14, color: textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: product.sizes.map((size) {
                              final isSelected = _selectedSize == size;
                              return GestureDetector(
                                onTap: () => _selectSize(size),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accent
                                        : sizeChipBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${size.name} — ${size.price.toInt()} смн',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.black
                                          : textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          product.description.isEmpty
                              ? 'Описание отсутствует.'
                              : product.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                        if (product.articul.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${settings.t('article')}: ${product.articul}',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          settings.t('similar_products').toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSimilarProducts(context, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(settings, product, images, isDark),
        ],
    );
  }

  Widget _buildSimilarProducts(BuildContext context, bool isDark) {
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF6B7280);
    if (_similarLoading) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_similarProducts.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Нет похожих товаров в этой категории',
            style: TextStyle(fontSize: 13, color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _similarProducts.length,
      itemBuilder: (context, i) {
        final p = _similarProducts[i];
        return ProductCard(
          product: p,
          onTap: () => Provider.of<NavigationProvider>(
            context,
            listen: false,
          ).showProductDetail(p),
        );
      },
    );
  }

  Widget _buildBottomBar(
    SettingsProvider settings,
    Product product,
    List<String> images,
    bool isDark,
  ) {
    final barBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final barBorder = isDark ? Colors.white10 : Colors.black12;
    final chipBg = isDark ? const Color(0xFF374151) : Colors.grey.shade200;
    final chipText = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: barBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Consumer<CartProvider>(
          builder: (context, cart, _) {
            final key = _cartKey(product);
            final inCart = cart.items.containsKey(key);
            final cartQty = inCart ? cart.items[key]!.qty : _qty;

            if (inCart) {
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          Navigator.of(context).pop();
                        }
                        Provider.of<NavigationProvider>(
                          context,
                          listen: false,
                        ).setIndex(3);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        settings.t('order_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => cart.removeSingleItem(key),
                          icon: Icon(Icons.remove, color: chipText, size: 22),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '$cartQty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: chipText,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => cart.addSingleItem(key),
                          icon: const Icon(
                            Icons.add,
                            color: AppColors.accent,
                            size: 22,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _addToCartAndGoToCart(settings, product, images),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      settings.t('buy'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _addToCart(settings, product, images),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentContrastText,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      settings.t('add_to_cart_btn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _addToCart(
    SettingsProvider settings,
    Product product,
    List<String> images,
  ) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(
      CartItem(
        id: product.id,
        name: _cartItemName(product),
        qty: _qty,
        price: _currentPrice,
        image: images.isNotEmpty ? images[0] : '',
      ),
    );
    showAddedToCartMessage(context, settings.t('added_to_cart'));
  }

  void _addToCartAndGoToCart(
    SettingsProvider settings,
    Product product,
    List<String> images,
  ) {
    _addToCart(settings, product, images);
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop();
    }
    Provider.of<NavigationProvider>(context, listen: false).setIndex(3);
  }
}
