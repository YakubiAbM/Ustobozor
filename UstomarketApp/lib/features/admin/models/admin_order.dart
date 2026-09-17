class AdminOrder {
  AdminOrder({
    required this.id,
    this.clientName,
    this.clientPhone,
    this.clientAddress,
    required this.totalPrice,
    this.paymentType,
    this.comment,
    this.createdAt,
    required this.status,
    required this.itemsCount,
    this.items = const [],
  });

  final int id;
  final String? clientName;
  final String? clientPhone;
  final String? clientAddress;
  final double totalPrice;
  final String? paymentType;
  final String? comment;
  final String? createdAt;
  final String status;
  final int itemsCount;
  final List<AdminOrderItem> items;

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    return AdminOrder(
      id: (json['id'] as num).toInt(),
      clientName: json['client_name']?.toString(),
      clientPhone: json['client_phone']?.toString(),
      clientAddress: json['client_address']?.toString(),
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      paymentType: json['payment_type']?.toString(),
      comment: json['comment']?.toString(),
      createdAt: json['created_at']?.toString(),
      status: json['status']?.toString() ?? 'new',
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      items: itemsRaw is List
          ? itemsRaw
              .map((e) => AdminOrderItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'processing':
        return 'В работе';
      case 'completed':
        return 'Выполнен';
      case 'canceled':
        return 'Отменён';
      default:
        return 'Новый';
    }
  }
}

class AdminOrderItem {
  AdminOrderItem({this.name, this.qty, this.price, this.productId});

  final String? name;
  final double? qty;
  final double? price;
  final int? productId;

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderItem(
      name: json['name']?.toString(),
      qty: (json['qty'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      productId: (json['product_id'] as num?)?.toInt(),
    );
  }
}
