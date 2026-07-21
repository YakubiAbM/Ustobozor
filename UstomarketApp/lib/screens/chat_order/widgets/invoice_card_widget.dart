import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../widgets/app_cached_image.dart';
import '../models/invoice_models.dart';

/// Накладная в чате: оформление как в истории заказов, список товаров карточками как в корзине,
/// внизу кнопки Добавить / Изменить / Удалить и кнопка «Оформить заказ».
class InvoiceCardWidget extends StatelessWidget {
  final InvoiceDraft invoice;
  final String invoiceTitle;
  final String totalLabel;
  final String addLabel;
  final String addProductBtnLabel;
  final String editQtyLabel;
  final String deleteLabel;
  final String placeOrderLabel;
  final String downloadInvoiceLabel;
  final VoidCallback onAddPressed;
  final VoidCallback onEditQtyPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onPlaceOrderPressed;
  final VoidCallback? onDownloadPressed;
  final void Function(int itemIndex, double newQty)? onQtyChanged;
  final void Function(InvoiceItem item)? onProductTap;

  const InvoiceCardWidget({
    super.key,
    required this.invoice,
    required this.invoiceTitle,
    required this.totalLabel,
    required this.addLabel,
    required this.addProductBtnLabel,
    required this.editQtyLabel,
    required this.deleteLabel,
    required this.placeOrderLabel,
    required this.downloadInvoiceLabel,
    required this.onAddPressed,
    required this.onEditQtyPressed,
    required this.onDeletePressed,
    required this.onPlaceOrderPressed,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок как в истории заказов: слева название, справа бейдж НАКЛАДНАЯ
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
                        'Черновик',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
          // Список товаров карточками как в корзине (по тапу — деталь товара)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: List.generate(invoice.items.length, (index) {
                final item = invoice.items[index];
                return _InvoiceItemCard(
                  item: item,
                  currency: invoice.currency,
                  theme: theme,
                  isDark: isDark,
                  onTap: onProductTap != null
                      ? () => onProductTap!(item)
                      : null,
                  itemIndex: index,
                  onQtyChanged: onQtyChanged != null
                      ? (double newQty) => onQtyChanged!(index, newQty)
                      : null,
                );
              }),
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
                  '${invoice.totalPrice.toInt()} ${invoice.currency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          // Чёткая кнопка «Добавить товар»
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add, size: 22),
                label: Text(
                  addProductBtnLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          // Кнопки: Изменить кол-во, Удалить
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionChip(
                  context,
                  Icons.edit,
                  editQtyLabel,
                  onEditQtyPressed,
                ),
                _actionChip(
                  context,
                  Icons.delete_outline,
                  deleteLabel,
                  onDeletePressed,
                ),
              ],
            ),
          ),
          // Кнопка «Скачать накладную»
          if (onDownloadPressed != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDownloadPressed,
                  icon: const Icon(Icons.download, size: 22),
                  label: Text(
                    downloadInvoiceLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          // Кнопка «Оформить заказ»
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPlaceOrderPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentContrastText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  placeOrderLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
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
              Icon(icon, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceItemCard extends StatelessWidget {
  final InvoiceItem item;
  final String currency;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback? onTap;
  final int itemIndex;
  final void Function(double newQty)? onQtyChanged;

  const _InvoiceItemCard({
    required this.item,
    required this.currency,
    required this.theme,
    required this.isDark,
    this.onTap,
    required this.itemIndex,
    this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasStepper = onQtyChanged != null;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  child: item.image.isEmpty
                      ? const Icon(Icons.image_outlined, color: Colors.grey)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AppCachedImage(
                            imagePath: item.image,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(10),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.price.toInt()} $currency',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (hasStepper)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.remove,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    final newQty = (item.qty - 1).clamp(
                                      1.0,
                                      double.infinity,
                                    );
                                    onQtyChanged!(newQty);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                                Text(
                                  item.qty == item.qty.toInt()
                                      ? '${item.qty.toInt()}'
                                      : '${item.qty}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                  onPressed: () => onQtyChanged!(item.qty + 1),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              '${item.qty} ${item.unit}',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.8,
                                ),
                              ),
                            ),
                          Text(
                            '${item.lineTotal.toInt()} $currency',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onTap != null && !hasStepper)
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
