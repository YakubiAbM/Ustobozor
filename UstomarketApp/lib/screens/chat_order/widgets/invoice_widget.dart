import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../../../widgets/app_cached_image.dart';
import '../models/chat_response_models.dart';

/// Электронная накладная Ustomarket (TZ §4.2): без вложенного скролла.
class InvoiceWidget extends StatelessWidget {
  final Cart cart;
  final String invoiceTitle;
  final String totalLabel;
  final String addProductBtnLabel;
  final String editQtyLabel;
  final String deleteLabel;
  final String downloadInvoiceLabel;
  final VoidCallback? onAddPressed;
  final VoidCallback? onEditQtyPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onDownloadPressed;
  final void Function(int itemIndex, double newQty)? onQtyChanged;
  final void Function(CartItem item)? onProductTap;

  const InvoiceWidget({
    super.key,
    required this.cart,
    required this.invoiceTitle,
    required this.totalLabel,
    required this.addProductBtnLabel,
    required this.editQtyLabel,
    required this.deleteLabel,
    required this.downloadInvoiceLabel,
    this.onAddPressed,
    this.onEditQtyPressed,
    this.onDeletePressed,
    this.onDownloadPressed,
    this.onQtyChanged,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 24, left: 8, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoiceTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Электронная накладная Ustomarket',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'НАКЛАДНАЯ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                for (var i = 0; i < cart.items.length; i++)
                  _InvoiceLine(
                    item: cart.items[i],
                    currency: cart.currency,
                    theme: theme,
                    isDark: isDark,
                    onTap: onProductTap != null
                        ? () => onProductTap!(cart.items[i])
                        : null,
                    onQtyChanged: onQtyChanged != null
                        ? (qty) => onQtyChanged!(i, qty)
                        : null,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${cart.totalPrice.toInt()} ${cart.currency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          if (onAddPressed != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: OutlinedButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add, size: 22),
                label: Text(addProductBtnLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (onEditQtyPressed != null || onDeletePressed != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onEditQtyPressed != null)
                    _ActionChip(
                      icon: Icons.edit,
                      label: editQtyLabel,
                      onTap: onEditQtyPressed!,
                    ),
                  if (onDeletePressed != null)
                    _ActionChip(
                      icon: Icons.delete_outline,
                      label: deleteLabel,
                      onTap: onDeletePressed!,
                    ),
                ],
              ),
            ),
          if (onDownloadPressed != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: OutlinedButton.icon(
                onPressed: onDownloadPressed,
                icon: const Icon(Icons.download, size: 22),
                label: Text(downloadInvoiceLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InvoiceLine extends StatelessWidget {
  final CartItem item;
  final String currency;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback? onTap;
  final void Function(double qty)? onQtyChanged;

  const _InvoiceLine({
    required this.item,
    required this.currency,
    required this.theme,
    required this.isDark,
    this.onTap,
    this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: item.image.isEmpty
                      ? const Icon(Icons.image_outlined, color: Colors.grey)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AppCachedImage(
                            imagePath: item.image,
                            fit: BoxFit.cover,
                            memCacheWidth: 112,
                            fallbackIcon: Icons.image_not_supported,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.qty == item.qty.toInt() ? item.qty.toInt() : item.qty} ${item.unit} × ${item.price.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.sum.toInt()} $currency',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                        fontSize: 14,
                      ),
                    ),
                    if (onQtyChanged != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () {
                              final q =
                                  (item.qty - 1).clamp(1.0, double.infinity);
                              onQtyChanged!(q);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add,
                                size: 18, color: AppColors.accent),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () => onQtyChanged!(item.qty + 1),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
