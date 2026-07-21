import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/product.dart';
import '../widgets/product_grid.dart';
import '../providers/settings_provider.dart';
import '../providers/navigation_provider.dart';
import '../repositories/product_repository.dart';

/// Экран товаров по бренду. GET /products?brand=... Показывается внутри MainLayout с нижней навигацией.
class BrandProductsScreen extends StatefulWidget {
  final String brandName;
  final VoidCallback? onBack;

  const BrandProductsScreen({super.key, required this.brandName, this.onBack});

  @override
  State<BrandProductsScreen> createState() => _BrandProductsScreenState();
}

class _BrandProductsScreenState extends State<BrandProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCachedProducts();
    _fetchProducts();
  }

  Future<void> _loadCachedProducts() async {
    final products = await ProductRepository.instance.getCachedProductsByBrand(
      widget.brandName,
    );
    if (!mounted || products.isEmpty) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ProductRepository.instance.refreshProductsByBrand(
        widget.brandName,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Text(
          widget.brandName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: onSurface.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _fetchProducts,
                      child: Text(settings.t('try_again')),
                    ),
                  ],
                ),
              ),
            )
          : _products.isEmpty
          ? Center(
              child: Text(
                'Нет товаров бренда ${widget.brandName}',
                style: TextStyle(color: onSurface.withOpacity(0.7)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchProducts,
              color: AppColors.accent,
              child: ProductGrid(
                products: _products,
                padding: const EdgeInsets.fromLTRB(15, 8, 15, 80),
                onProductTap: (p) {
                  widget.onBack?.call();
                  context.read<NavigationProvider>().showProductDetail(p);
                },
              ),
            ),
    );
  }
}
