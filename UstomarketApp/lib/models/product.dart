class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String subcategory;
  final String unit;
  final String description;
  final String articul;
  final List<String> photos;
  final bool isRecommended;
  final List<ProductSize> sizes; // Список размеров
  final List<ProductColor> colors;
  final String brand;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.subcategory,
    required this.unit,
    required this.description,
    required this.articul,
    required this.photos,
    required this.isRecommended,
    required this.sizes,
    required this.colors,
    this.brand = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Без названия',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      category: json['category'] ?? '',
      subcategory: json['subcategory'] ?? '',
      unit: json['unit'] ?? 'шт',
      description: json['description'] ?? '',
      articul: json['articul'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      isRecommended: json['is_recommended'] ?? false,
      sizes: (json['sizes'] as List? ?? []).map((e) => ProductSize.fromJson(e)).toList(),
      colors: (json['colors'] as List? ?? []).map((e) => ProductColor.fromJson(e)).toList(),
      brand: (json['brand'] as String? ?? '').trim(),
    );
  }
}

class ProductSize {
  final String name;
  final double price;

  ProductSize({required this.name, required this.price});

  factory ProductSize.fromJson(Map<String, dynamic> json) {
    return ProductSize(
      name: json['name'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }
}

class ProductColor {
  final String name;
  final String code;
  final String hex;

  ProductColor({required this.name, required this.code, required this.hex});

  factory ProductColor.fromJson(Map<String, dynamic> json) {
    final hex = json['hex']?.toString() ?? json['value']?.toString() ?? '#000000';
    return ProductColor(
      name: json['name'] ?? '',
      code: json['code']?.toString() ?? hex,
      hex: hex,
    );
  }
}