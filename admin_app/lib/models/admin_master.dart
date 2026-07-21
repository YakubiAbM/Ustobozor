class AdminMaster {
  AdminMaster({
    required this.id,
    this.name,
    this.phone,
    required this.points,
    required this.debt,
    required this.experience,
    required this.rating,
    this.categories = const [],
    this.image,
  });

  final int id;
  final String? name;
  final String? phone;
  final int points;
  final double debt;
  final int experience;
  final double rating;
  final List<String> categories;
  final String? image;

  factory AdminMaster.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'];
    return AdminMaster(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5,
      categories: cats is List ? cats.map((e) => e.toString()).toList() : [],
      image: json['image']?.toString(),
    );
  }
}
