/// Черновик накладной из чата.
class InvoiceDraft {
  final List<InvoiceItem> items;
  final double totalPrice;
  final String currency;

  const InvoiceDraft({
    required this.items,
    required this.totalPrice,
    this.currency = 'смн',
  });

  factory InvoiceDraft.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return InvoiceDraft(
      items: itemsList.map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>)).toList(),
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'смн',
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'total_price': totalPrice,
        'currency': currency,
      };
}

class InvoiceItem {
  final int productId;
  final String name;
  final double qty;
  final String unit;
  final double price;
  final String image;
  final double lineTotal;

  const InvoiceItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unit,
    required this.price,
    required this.image,
    required this.lineTotal,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      productId: json['product_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'шт',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      image: json['image'] as String? ?? '',
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'qty': qty,
        'unit': unit,
        'price': price,
        'image': image,
        'line_total': lineTotal,
      };
}
