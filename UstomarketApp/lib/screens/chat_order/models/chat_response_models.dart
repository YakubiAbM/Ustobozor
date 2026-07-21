/// Immutable models for /chat/* API responses (TZ §2).
class ChatResponse {
  final String? sessionId;
  final String? status;
  final String type; // 'pick' | 'invoice' | text variants
  final PendingItem? currentPendingItem;
  final Cart? cart;
  final String? message;

  const ChatResponse({
    this.sessionId,
    this.status,
    required this.type,
    this.currentPendingItem,
    this.cart,
    this.message,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json, {String? sessionId}) {
    final type = json['type'] as String? ?? 'text';
    PendingItem? pending;
    if (type == 'pick' ||
        json['options'] != null ||
        json['item_index'] != null) {
      pending = PendingItem.fromJson(json);
    }
    Cart? cart;
    final draftJson = json['draft'] ?? json['invoice'];
    if (draftJson is Map<String, dynamic>) {
      cart = Cart.fromJson(draftJson);
    }
    return ChatResponse(
      sessionId: sessionId ?? json['session_id'] as String?,
      status: json['status'] as String?,
      type: type,
      currentPendingItem: pending,
      cart: cart,
      message: json['message'] as String? ?? json['prompt'] as String?,
    );
  }
}

class PendingItem {
  final int itemIndex;
  final String userQuery;
  final double qty;
  final List<ProductOption> options;

  const PendingItem({
    required this.itemIndex,
    required this.userQuery,
    required this.qty,
    required this.options,
  });

  factory PendingItem.fromJson(Map<String, dynamic> json) {
    final opts = json['options'] as List<dynamic>? ?? [];
    final prompt = json['prompt'] as String? ?? '';
    final query = json['query'] as String? ?? '';
    return PendingItem(
      itemIndex: json['item_index'] as int? ?? 0,
      userQuery: prompt.isNotEmpty ? prompt : query,
      qty: (json['qty'] as num?)?.toDouble() ?? 1,
      options: opts
          .map((e) => ProductOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProductOption {
  final int productId;
  final String name;
  final String label;
  final double price;
  final String unit;
  final String image;

  const ProductOption({
    required this.productId,
    required this.name,
    required this.label,
    required this.price,
    this.unit = 'шт',
    this.image = '',
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int? ?? json['product_id'] as int? ?? 0;
    final name = json['name'] as String? ?? '';
    final label = json['label'] as String? ?? name;
    return ProductOption(
      productId: id,
      name: name,
      label: label,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'шт',
      image: json['image'] as String? ?? '',
    );
  }
}

class Cart {
  final List<CartItem> items;
  final double totalPrice;
  final String currency;

  const Cart({
    required this.items,
    required this.totalPrice,
    this.currency = 'TJS',
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return Cart(
      items: itemsList
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'TJS',
    );
  }

  bool get isEmpty => items.isEmpty;
}

class CartItem {
  final int productId;
  final String name;
  final double qty;
  final double price;
  final double sum;
  final String unit;
  final String image;

  const CartItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
    required this.sum,
    this.unit = 'шт',
    this.image = '',
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      sum: (json['line_total'] as num?)?.toDouble() ??
          (json['sum'] as num?)?.toDouble() ??
          0,
      unit: json['unit'] as String? ?? 'шт',
      image: json['image'] as String? ?? '',
    );
  }
}
