class Order {
  final int id;
  final String number;
  final double total;
  final String date;
  final String status;
  final List<OrderItem> items;
  final String? clientName;
  final String? clientPhone;

  Order({
    required this.id,
    required this.number,
    required this.total,
    required this.date,
    required this.status,
    required this.items,
    this.clientName,
    this.clientPhone,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderItem> itemsList = [];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final i in rawItems) {
        try {
          final m = i is Map<String, dynamic> ? i : (i is Map ? Map<String, dynamic>.from(i) : <String, dynamic>{});
          itemsList.add(OrderItem.fromJson(m));
        } catch (_) {}
      }
    }

    final id = json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0;
    final number = json['number']?.toString()?.trim();
    return Order(
      id: id,
      number: number != null && number.isNotEmpty ? number : id.toString(),
      total: double.tryParse(json['total_price']?.toString() ?? '') ?? 0.0,
      date: json['created_at']?.toString() ?? '',
      status: json['status']?.toString() ?? 'new',
      items: itemsList,
      clientName: json['client_name']?.toString(),
      clientPhone: json['client_phone']?.toString(),
    );
  }
}

class OrderItem {
  final String name;
  final int qty;
  final double price;
  final String unit;

  OrderItem({required this.name, required this.qty, required this.price, this.unit = 'шт'});

  static String _safeName(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.replaceAll(RegExp(r'\[object Object\]'), '').trim();
    if (value is Map || value is List) return ''; // не подставлять объект в название
    final s = value.toString();
    return s.replaceAll(RegExp(r'\[object Object\]'), '').trim();
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    int qty = 1;
    final q = json['qty'];
    if (q is int) {
      qty = q;
    } else if (q is num) {
      qty = q.toInt();
    } else if (q != null) {
      qty = int.tryParse(q.toString()) ?? (double.tryParse(q.toString())?.toInt() ?? 1);
    }
    return OrderItem(
      name: _safeName(json['name']),
      qty: qty,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      unit: json['unit']?.toString() ?? 'шт',
    );
  }
}