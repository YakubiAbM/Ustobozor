import 'dart:convert';

import '../../../api_client.dart';

class MasterListing {
  MasterListing({
    required this.id,
    required this.name,
    required this.phone,
    required this.description,
    required this.city,
    required this.experience,
    required this.image,
    required this.categories,
    required this.portfolio,
    required this.moderationStatus,
    required this.moderationNote,
  });

  final int id;
  final String name;
  final String phone;
  final String description;
  final String city;
  final int experience;
  final String image;
  final List<String> categories;
  final List<String> portfolio;
  final String moderationStatus;
  final String moderationNote;

  factory MasterListing.fromJson(Map<String, dynamic> json) {
    final cats = json['categories'];
    final port = json['portfolio'];
    return MasterListing(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      image: json['image']?.toString() ?? '',
      categories: cats is List ? cats.map((e) => e.toString()).toList() : [],
      portfolio: port is List ? port.map((e) => e.toString()).toList() : [],
      moderationStatus: json['moderation_status']?.toString() ?? 'draft',
      moderationNote: json['moderation_note']?.toString() ?? '',
    );
  }
}

class MasterListingApi {
  MasterListingApi._();
  static final instance = MasterListingApi._();

  Future<({MasterListing? listing, List<String> categories})> getMyListing(
    String token,
  ) async {
    final r = await apiGetWithBearer('/masters/me/listing', token);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! Map) {
      return (listing: null, categories: <String>[]);
    }
    final listingRaw = data['listing'];
    final catsRaw = data['categories'];
    return (
      listing: listingRaw is Map
          ? MasterListing.fromJson(Map<String, dynamic>.from(listingRaw))
          : null,
      categories: catsRaw is List
          ? catsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : <String>[],
    );
  }

  Future<MasterListing> submit({
    required String token,
    required String name,
    required String category,
    required String photoBase64,
    String description = '',
    String city = '',
    int? experience,
    List<String> portfolioBase64 = const [],
  }) async {
    final r = await apiPostWithBearer(
      '/masters/me/listing',
      token,
      body: {
        'name': name,
        'category': category,
        'description': description,
        'city': city,
        'experience': experience,
        'photo_base64': photoBase64,
        'portfolio_base64': portfolioBase64,
      },
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! Map || data['listing'] is! Map) {
      throw Exception(data is Map ? (data['detail'] ?? 'Ошибка') : 'Ошибка');
    }
    return MasterListing.fromJson(
      Map<String, dynamic>.from(data['listing'] as Map),
    );
  }
}
