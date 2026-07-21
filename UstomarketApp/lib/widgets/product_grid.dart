import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/navigation_provider.dart';
import 'product_card.dart';

/// Сетка товаров с [RepaintBoundary] и стабильными ключами — для каталога и главной.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    this.padding = const EdgeInsets.all(0),
    this.shrinkWrap = false,
    this.physics,
    this.onProductTap,
  });

  final List<Product> products;
  final EdgeInsets padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final void Function(Product product)? onProductTap;

  static const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.6,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  );

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : null),
      addRepaintBoundaries: true,
      cacheExtent: 400,
      gridDelegate: gridDelegate,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return RepaintBoundary(
          key: ValueKey('product_${product.id}'),
          child: ProductCard(
            product: product,
            onTap: () {
              if (onProductTap != null) {
                onProductTap!(product);
              } else {
                context.read<NavigationProvider>().showProductDetail(product);
              }
            },
          ),
        );
      },
    );
  }
}

/// Sliver-вариант для [CustomScrollView] на главной.
class ProductGridSliver extends StatelessWidget {
  const ProductGridSliver({
    super.key,
    required this.products,
    this.onProductTap,
  });

  final List<Product> products;
  final void Function(Product product)? onProductTap;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: ProductGrid.gridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final product = products[index];
          return RepaintBoundary(
            key: ValueKey('product_${product.id}'),
            child: ProductCard(
              product: product,
              onTap: () {
                if (onProductTap != null) {
                  onProductTap!(product);
                } else {
                  context.read<NavigationProvider>().showProductDetail(product);
                }
              },
            ),
          );
        },
        childCount: products.length,
        addRepaintBoundaries: false,
      ),
    );
  }
}
