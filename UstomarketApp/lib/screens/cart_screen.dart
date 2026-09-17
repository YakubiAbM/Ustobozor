import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/master_auth_provider.dart';
import '../repositories/product_repository.dart';
import '../widgets/app_cached_image.dart';
import 'checkout_screen.dart';
import 'master_auth/master_login_phone_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).ensureSelectionInit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final cartKeys = cart.items.keys.toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 15, 15, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () {
                      Provider.of<NavigationProvider>(
                        context,
                        listen: false,
                      ).setIndex(NavigationProvider.tabMaterials);
                    },
                    tooltip: settings.t('materials'),
                  ),
                  Expanded(
                    child: Text(
                      'Ustomarket',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${settings.t('my_cart')} (${cart.itemCount})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (cart.items.isNotEmpty)
                    TextButton(
                      onPressed: () => cart.clear(),
                      child: Text(
                        settings.t('clear_all'),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (cart.items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 15, 8),
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 1.35,
                      child: Checkbox(
                        value: cart.allSelected,
                        onChanged: (_) {
                          if (cart.allSelected) {
                            cart.deselectAll();
                          } else {
                            cart.selectAll();
                          }
                        },
                        activeColor: AppColors.accent,
                        fillColor: WidgetStateProperty.resolveWith(
                          (states) => AppColors.accent,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      'Все товары',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: cart.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            settings.t('empty_cart_title'),
                            style: TextStyle(
                              fontSize: 18,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings.t('empty_cart_desc'),
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 100),
                      itemCount: cart.items.length,
                      itemBuilder: (ctx, i) {
                        String key = cartKeys[i];
                        CartItem item = cart.items[key]!;
                        return _CartItemTile(
                          itemKey: key,
                          item: item,
                          selected: cart.isSelected(key),
                          onToggleSelect: () => cart.toggleSelection(key),
                          onRemove: () => cart.removeItem(key),
                          onDecrease: () => cart.removeSingleItem(key),
                          onIncrease: () => cart.addSingleItem(key),
                          onImageTap: () =>
                              _openProductDetail(context, item.id),
                          theme: theme,
                        );
                      },
                    ),
            ),
            if (cart.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${settings.t('total')} (${cart.selectedCount})',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.8,
                              ),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${cart.selectedTotalAmount.toInt()} ',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const Text(
                                'смн',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: ElevatedButton(
                        onPressed: cart.selectedCount == 0
                            ? null
                            : () async {
                                final canProceed =
                                    await _ensureAuthorizedForCheckout(
                                  context,
                                );
                                if (!canProceed || !context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CheckoutScreen(),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.accentContrastText,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          settings.t('checkout_btn'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureAuthorizedForCheckout(BuildContext context) async {
    final master = Provider.of<MasterAuthProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (master.isLoggedIn) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(settings.t('auth_required_title')),
        content: Text(settings.t('auth_required_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(settings.t('close')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(settings.t('auth_required_login_button')),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MasterLoginPhoneScreen(),
        ),
      );
    }

    return false;
  }

  Future<void> _openProductDetail(
    BuildContext context,
    String productId,
  ) async {
    try {
      final product = await ProductRepository.instance.getProductById(
        productId,
      );
      if (!context.mounted) return;
      if (product != null) {
        Provider.of<NavigationProvider>(
          context,
          listen: false,
        ).showProductDetail(product);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Товар не найден')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить товар')),
        );
      }
    }
  }
}

class _CartItemTile extends StatelessWidget {
  final String itemKey;
  final CartItem item;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onRemove;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onImageTap;
  final ThemeData theme;

  const _CartItemTile({
    required this.itemKey,
    required this.item,
    required this.selected,
    required this.onToggleSelect,
    required this.onRemove,
    required this.onDecrease,
    required this.onIncrease,
    required this.onImageTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: (_) => onToggleSelect(),
            activeColor: AppColors.accent,
            fillColor: WidgetStateProperty.resolveWith(
              (states) => AppColors.accent,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onImageTap,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
              child: item.image.isEmpty
                  ? const Icon(Icons.image, color: Colors.grey)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppCachedImage(
                        imagePath: item.image,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(12),
                        fallbackIcon: Icons.error,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toInt()} смн',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.lineTotal.toInt()} смн',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 22,
                ),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.remove,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: onDecrease,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Text(
                    '${item.qty}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                    color: onSurface,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    onPressed: onIncrease,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
