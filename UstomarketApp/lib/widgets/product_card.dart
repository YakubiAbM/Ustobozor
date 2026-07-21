import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/settings_provider.dart';
import 'app_cached_image.dart';

/// Карточка товара в сетке: фото на сером фоне + цена/вес + название.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  String _cartKey(CartProvider cart) {
    final parts = <String>[product.name];
    if (product.sizes.isNotEmpty) parts.add(product.sizes.first.name);
    if (product.colors.isNotEmpty) parts.add(product.colors.first.name);
    final name = parts.length == 1
        ? product.name
        : '${parts[0]} (${parts.sublist(1).join(', ')})';
    return '${product.id}_$name';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    final imagePlaceholderColor =
        isDark ? const Color(0xFF1A202C) : Colors.grey.shade200;
    final imagePath = product.photos.isNotEmpty ? product.photos[0] : '';
    final unitLabel = product.unit.trim().isEmpty ? 'шт' : product.unit.trim();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: imagePlaceholderColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imagePath.isEmpty
                        ? const Center(
                            child: Icon(Icons.image, color: Colors.grey, size: 40),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final dpr = MediaQuery.devicePixelRatioOf(context);
                              // cover: кэшируем по большей стороне ячейки (без memCacheHeight)
                              final logicalSide = constraints.maxWidth >
                                      constraints.maxHeight
                                  ? constraints.maxWidth
                                  : constraints.maxHeight;
                              final cacheSide =
                                  (logicalSide * dpr).round().clamp(1, 720);
                              return AppCachedImage(
                                imagePath: imagePath,
                                fit: BoxFit.cover,
                                memCacheWidth: cacheSide,
                                maxMemCacheSide: 720,
                                fallbackIcon: Icons.image,
                              );
                            },
                          ),
                  ),
                ),
                if (product.isRecommended)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'HIT',
                        style: TextStyle(
                          color: AppColors.accentContrastText,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  right: 10,
                  child: Selector<CartProvider, _CartBadgeState>(
                    selector: (_, cart) {
                      final key = _cartKey(cart);
                      final item = cart.items[key];
                      return _CartBadgeState(
                        inCart: item != null,
                        qty: item?.qty ?? 0,
                        cartKey: key,
                      );
                    },
                    builder: (context, state, _) {
                      if (state.inCart) {
                        return _QuantityBar(cartKey: state.cartKey);
                      }
                      return _AddToCartButton(
                        product: product,
                        imagePath: imagePath,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${product.price.toInt()} смн',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ $unitLabel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBadgeState {
  const _CartBadgeState({
    required this.inCart,
    required this.qty,
    required this.cartKey,
  });

  final bool inCart;
  final int qty;
  final String cartKey;

  @override
  bool operator ==(Object other) =>
      other is _CartBadgeState &&
      other.inCart == inCart &&
      other.qty == qty &&
      other.cartKey == cartKey;

  @override
  int get hashCode => Object.hash(inCart, qty, cartKey);
}

class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({
    required this.product,
    required this.imagePath,
  });

  final Product product;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final parts = <String>[product.name];
        if (product.sizes.isNotEmpty) parts.add(product.sizes.first.name);
        if (product.colors.isNotEmpty) parts.add(product.colors.first.name);
        final name = parts.length == 1
            ? product.name
            : '${parts[0]} (${parts.sublist(1).join(', ')})';
        final price = product.sizes.isNotEmpty
            ? product.sizes.first.price
            : product.price;
        context.read<CartProvider>().addItem(
          CartItem(
            id: product.id,
            name: name,
            qty: 1,
            price: price,
            image: imagePath,
          ),
        );
        final settings = context.read<SettingsProvider>();
        showAddedToCartMessage(context, settings.t('added_to_cart'));
      },
      child: const CircleAvatar(
        backgroundColor: AppColors.accent,
        radius: 20,
        child: Icon(Icons.shopping_cart, color: AppColors.accentContrastText, size: 22),
      ),
    );
  }
}

class _QuantityBar extends StatelessWidget {
  const _QuantityBar({required this.cartKey});

  final String cartKey;

  @override
  Widget build(BuildContext context) {
    return Selector<CartProvider, int>(
      selector: (_, cart) => cart.items[cartKey]?.qty ?? 0,
      builder: (context, qty, _) {
        final cart = context.read<CartProvider>();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => cart.removeSingleItem(cartKey),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.remove, color: AppColors.accentContrastText, size: 20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$qty',
                  style: const TextStyle(
                    color: AppColors.accentContrastText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => cart.addSingleItem(cartKey),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.add, color: AppColors.accentContrastText, size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
