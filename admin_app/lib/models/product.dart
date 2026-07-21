class AdminProduct {
  final int id;
  final String name;
  final double price;
  final String? category;
  final String? subcategory;
  final String? description;
  final String? unit;
  final String? image;
  final String? articul;
  final String? brand;
  final bool inStock;
  final List<String> photos;

  AdminProduct({
    required this.id,
    required this.name,
    required this.price,
    this.category,
    this.subcategory,
    this.description,
    this.unit,
    this.image,
    this.articul,
    this.brand,
    this.inStock = true,
    this.photos = const [],
  });

  factory AdminProduct.fromJson(Map<String, dynamic> json) {
    return AdminProduct(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num).toDouble(),
      category: json['category']?.toString(),
      subcategory: json['subcategory']?.toString(),
      description: json['description']?.toString(),
      unit: json['unit']?.toString(),
      image: json['image']?.toString(),
      articul: json['articul']?.toString(),
      brand: json['brand']?.toString(),
      inStock: json['in_stock'] != false,
      photos: (json['photos'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// DTO для формы "Новый товар / Редактировать товар".
class AdminProductDraft {
  final String name;
  final double price;
  final String? brand;
  final String? category;
  final String? newCategory;
  final String? subcategory;
  final String? newSubcategory;
  final String? articul;
  final String? description;
  final String? unit;
  final List<String> sizesNames;
  final List<double> sizesPrices;
  final List<String> colorsNames;
  final List<String> colorsValues;

  const AdminProductDraft({
    required this.name,
    required this.price,
    this.brand,
    this.category,
    this.newCategory,
    this.subcategory,
    this.newSubcategory,
    this.articul,
    this.description,
    this.unit = 'шт',
    this.sizesNames = const [],
    this.sizesPrices = const [],
    this.colorsNames = const [],
    this.colorsValues = const [],
  });
}

