class AdminMaster {
  AdminMaster({
    required this.id,
    this.name,
    this.phone,
    required this.points,
    required this.debt,
    required this.experience,
    required this.rating,
    this.city = '',
    this.categories = const [],
    this.image,
    this.moderationStatus = 'approved',
    this.moderationNote = '',
  });

  final int id;
  final String? name;
  final String? phone;
  final int points;
  final double debt;
  final int experience;
  final double rating;
  final String city;
  final List<String> categories;
  final String? image;
  final String moderationStatus;
  final String moderationNote;

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
      city: json['city']?.toString() ?? '',
      categories: cats is List ? cats.map((e) => e.toString()).toList() : [],
      image: json['image']?.toString(),
      moderationStatus: json['moderation_status']?.toString() ?? 'approved',
      moderationNote: json['moderation_note']?.toString() ?? '',
    );
  }
}
