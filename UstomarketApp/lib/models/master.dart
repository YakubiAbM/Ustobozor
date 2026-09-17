/// Элемент прайс-листа мастера
class MasterPriceItem {
  final String name;
  final num price;
  final String unit;

  MasterPriceItem({required this.name, required this.price, this.unit = 'шт'});

  static MasterPriceItem? fromJson(dynamic e) {
    if (e is! Map<String, dynamic>) return null;
    final name = e['name']?.toString() ?? e['service']?.toString() ?? '';
    if (name.isEmpty) return null;
    final price = (e['price'] is num) ? e['price'] as num : num.tryParse(e['price']?.toString() ?? '') ?? 0;
    final unit = e['unit']?.toString() ?? 'шт';
    return MasterPriceItem(name: name, price: price, unit: unit);
  }
}

class Master {
  final int id;
  final String name;
  final String phone;
  final String category;
  final String description;
  final String image;
  final double rating;
  final int reviewsCount;
  final String city;
  final String? priceFrom;
  final int? experience;
  final List<MasterPriceItem> priceList;
  final List<String> workExamples;

  Master({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    required this.description,
    required this.image,
    required this.rating,
    this.reviewsCount = 0,
    this.city = '',
    this.priceFrom,
    this.experience,
    List<MasterPriceItem>? priceList,
    List<String>? workExamples,
  })  : priceList = priceList ?? [],
        workExamples = workExamples ?? [];

  List<String> get categoriesList {
    if (category.isEmpty) return [];
    return category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  factory Master.fromJson(Map<String, dynamic> json) {
    // categories: массив ["Ранг, Кафел"] или строка "category"
    String categoryStr = json['category']?.toString() ?? '';
    if (json['categories'] is List) {
      final list = (json['categories'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      categoryStr = list.join(', ');
    }

    // services или price_list — прайс
    List<MasterPriceItem> priceList = [];
    final servicesRaw = json['services'] ?? json['price_list'];
    if (servicesRaw is List) {
      for (final e in servicesRaw) {
        final map = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
        final item = MasterPriceItem.fromJson(map);
        if (item != null) priceList.add(item);
      }
    }

    // portfolio или work_examples — примеры работ
    List<String> workExamples = [];
    final portfolioRaw = json['portfolio'] ?? json['work_examples'];
    if (portfolioRaw is List) {
      for (final e in portfolioRaw) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) workExamples.add(s);
      }
    }

    String? priceFrom = json['price_from']?.toString() ?? json['price']?.toString();
    if (priceFrom == null && priceList.isNotEmpty) priceFrom = priceList.first.price.toString();

    final cityRaw = json['city']?.toString().trim() ?? '';

    return Master(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Мастер',
      phone: json['phone']?.toString() ?? '',
      category: categoryStr,
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      rating: double.tryParse(json['rating'].toString()) ?? 5.0,
      reviewsCount: int.tryParse('${json['reviews_count'] ?? 0}') ?? 0,
      city: cityRaw == 'null' ? '' : cityRaw,
      priceFrom: priceFrom,
      experience: json['experience'] is int ? json['experience'] as int? : int.tryParse(json['experience']?.toString() ?? ''),
      priceList: priceList,
      workExamples: workExamples,
    );
  }
}
