import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/product.dart';

class ProductDetailScreen extends StatelessWidget {
  final AdminProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleStock;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    this.onToggleStock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = product.image != null && product.image!.isNotEmpty
        ? buildImageUrl(product.image)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали товара'),
        actions: [
          if (onToggleStock != null)
            IconButton(
              tooltip: product.inStock ? 'Снять с продажи' : 'В наличие',
              onPressed: () {
                onToggleStock!();
                Navigator.pop(context);
              },
              icon: Icon(product.inStock ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 180,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover),
                  )
                : const Center(
                    child: Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary),
                  ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      if (!product.inStock)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Нет в наличии',
                            style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _row('Название', product.name),
                      _row('Код / штрихкод', product.articul ?? '-'),
                      _row('Бренд', product.brand ?? '—'),
                      _row('Категория', product.category ?? 'Без категории'),
                      _row('Подкатегория', product.subcategory ?? '—'),
                      _row('Ед. измерения', product.unit ?? 'шт'),
                      _row('Цена продажи', '${product.price.toStringAsFixed(0)} TJS'),
                      _row('Описание', product.description ?? '—'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: onEdit, child: const Text('Редактировать')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Удалить'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
