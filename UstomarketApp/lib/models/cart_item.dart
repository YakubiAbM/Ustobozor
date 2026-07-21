class CartItem {
  final String id;
  final String name;
  final int qty;
  final double price;
  final String image;

  CartItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.price,
    required this.image,
  });

  double get lineTotal => price * qty;

  Map<String, dynamic> toJson() => {
        'id': int.tryParse(id) ?? 0,
        'name': name,
        'qty': qty,
        'price': price.toDouble(),
        'image': image.isNotEmpty ? image : '',
      };
}
