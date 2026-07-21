class OrderInvoiceItem {
  OrderInvoiceItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.unit,
    required this.lineTotal,
  });

  final String name;
  final double qty;
  final double price;
  final String unit;
  final double lineTotal;

  factory OrderInvoiceItem.fromJson(Map<String, dynamic> json) {
    return OrderInvoiceItem(
      name: json['name']?.toString() ?? '—',
      qty: (json['qty'] as num?)?.toDouble() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? 'шт',
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderInvoice {
  OrderInvoice({
    required this.orderId,
    required this.invoiceNumber,
    required this.date,
    this.clientName,
    this.clientPhone,
    this.clientAddress,
    required this.items,
    required this.total,
    this.paymentType,
    this.comment,
  });

  final int orderId;
  final String invoiceNumber;
  final String date;
  final String? clientName;
  final String? clientPhone;
  final String? clientAddress;
  final List<OrderInvoiceItem> items;
  final double total;
  final String? paymentType;
  final String? comment;

  factory OrderInvoice.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    return OrderInvoice(
      orderId: (json['order_id'] as num).toInt(),
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      clientName: json['client_name']?.toString(),
      clientPhone: json['client_phone']?.toString(),
      clientAddress: json['client_address']?.toString(),
      items: itemsRaw is List
          ? itemsRaw.map((e) => OrderInvoiceItem.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paymentType: json['payment_type']?.toString(),
      comment: json['comment']?.toString(),
    );
  }
}
