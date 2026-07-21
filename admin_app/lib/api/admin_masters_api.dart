import 'dart:convert';

import 'admin_http.dart';

class MasterServiceDraft {
  MasterServiceDraft({required this.name, this.price = 0, this.unit = ''});

  final String name;
  final double price;
  final String unit;

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'unit': unit,
      };

  factory MasterServiceDraft.fromJson(Map<String, dynamic> json) {
    return MasterServiceDraft(
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? '',
    );
  }
}

class MasterDraft {
  MasterDraft({
    required this.name,
    required this.phone,
    this.description = '',
    this.experience = 0,
    this.categories = const [],
    this.newCategory,
    this.services = const [],
  });

  final String name;
  final String phone;
  final String description;
  final int experience;
  final List<String> categories;
  final String? newCategory;
  final List<MasterServiceDraft> services;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'description': description,
        'experience': experience,
        'categories': categories,
        if (newCategory != null && newCategory!.isNotEmpty) 'new_category': newCategory,
        'services': services.map((s) => s.toJson()).toList(),
      };
}

class AdminMastersCrudApi {
  static Future<List<String>> fetchCategories() async {
    final res = await AdminHttp.get('/admin/api/masters/meta/categories');
    if (res.statusCode != 200) throw Exception('Ошибка категорий мастеров');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final raw = data['categories'];
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static Future<AdminMasterDetail> create(MasterDraft draft) async {
    final res = await AdminHttp.post('/admin/api/masters', body: draft.toJson());
    if (res.statusCode != 200) {
      final err = _tryDetail(res);
      throw Exception(err ?? 'Не удалось создать мастера');
    }
    return AdminMasterDetail.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<AdminMasterDetail> update(int id, MasterDraft draft) async {
    final res = await AdminHttp.put('/admin/api/masters/$id', body: draft.toJson());
    if (res.statusCode != 200) {
      final err = _tryDetail(res);
      throw Exception(err ?? 'Не удалось обновить мастера');
    }
    return AdminMasterDetail.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<void> delete(int id) async {
    final res = await AdminHttp.delete('/admin/api/masters/$id');
    if (res.statusCode != 200) throw Exception('Не удалось удалить мастера');
  }

  static Future<AdminMasterDetail> fetchDetail(int masterId) async {
    final res = await AdminHttp.get('/admin/api/masters/$masterId');
    if (res.statusCode != 200) throw Exception('Ошибка загрузки мастера');
    return AdminMasterDetail.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static String? _tryDetail(dynamic res) {
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['detail'] != null) return data['detail'].toString();
    } catch (_) {}
    return null;
  }
}

class AdminMasterDetail {
  AdminMasterDetail({
    required this.id,
    this.name,
    this.phone,
    required this.points,
    required this.debt,
    required this.experience,
    required this.ordersCount,
    required this.totalSpent,
    this.description,
    this.categories = const [],
    this.services = const [],
    this.portfolio = const [],
  });

  final int id;
  final String? name;
  final String? phone;
  final int points;
  final double debt;
  final int experience;
  final int ordersCount;
  final double totalSpent;
  final String? description;
  final List<String> categories;
  final List<MasterServiceDraft> services;
  final List<String> portfolio;

  factory AdminMasterDetail.fromJson(Map<String, dynamic> json) {
    final catsRaw = json['categories'];
    final servRaw = json['services'];
    final portRaw = json['portfolio'];
    return AdminMasterDetail(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      ordersCount: (json['orders_count'] as num?)?.toInt() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString(),
      categories: catsRaw is List ? catsRaw.map((e) => e.toString()).toList() : [],
      services: servRaw is List
          ? servRaw.map((e) => MasterServiceDraft.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      portfolio: portRaw is List ? portRaw.map((e) => e.toString()).toList() : [],
    );
  }
}
