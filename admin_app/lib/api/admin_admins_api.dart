import 'dart:convert';

import 'admin_http.dart';

class AdminStaffUser {
  AdminStaffUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.isSuperadmin,
    required this.permissions,
  });

  final int id;
  final String name;
  final String phone;
  final bool isSuperadmin;
  final List<String> permissions;

  factory AdminStaffUser.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'];
    return AdminStaffUser(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '—',
      phone: json['phone']?.toString() ?? '—',
      isSuperadmin: json['is_superadmin'] == true,
      permissions: perms is List ? perms.map((e) => e.toString()).toList() : [],
    );
  }
}

class AdminScopeInfo {
  AdminScopeInfo({required this.scopes, required this.labels});

  final List<String> scopes;
  final Map<String, String> labels;

  factory AdminScopeInfo.fromJson(Map<String, dynamic> json) {
    final labelsRaw = json['labels'];
    return AdminScopeInfo(
      scopes: (json['scopes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      labels: labelsRaw is Map
          ? labelsRaw.map((k, v) => MapEntry(k.toString(), v.toString()))
          : {},
    );
  }
}

class AdminStaffDraft {
  AdminStaffDraft({
    this.name = '',
    required this.phone,
    required this.pin,
    required this.permissions,
  });

  final String name;
  final String phone;
  final String pin;
  final List<String> permissions;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'pin': pin,
        'permissions': permissions,
      };
}

class AdminStaffApi {
  static Future<AdminScopeInfo> fetchScopes() async {
    final res = await AdminHttp.get('/admin/api/admins/scopes');
    if (res.statusCode != 200) throw Exception('Нет доступа');
    return AdminScopeInfo.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<List<AdminStaffUser>> fetchAll() async {
    final res = await AdminHttp.get('/admin/api/admins');
    if (res.statusCode != 200) throw Exception('Ошибка загрузки админов');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return [];
    return data.map((e) => AdminStaffUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<AdminStaffUser> create(AdminStaffDraft draft) async {
    final res = await AdminHttp.post('/admin/api/admins', body: draft.toJson());
    if (res.statusCode != 200) throw Exception(_detail(res) ?? 'Не удалось добавить админа');
    return AdminStaffUser.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<AdminStaffUser> update(int id, AdminStaffDraft draft) async {
    final res = await AdminHttp.put('/admin/api/admins/$id', body: draft.toJson());
    if (res.statusCode != 200) throw Exception(_detail(res) ?? 'Не удалось сохранить');
    return AdminStaffUser.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<void> remove(int id) async {
    final res = await AdminHttp.delete('/admin/api/admins/$id');
    if (res.statusCode != 200) throw Exception(_detail(res) ?? 'Не удалось удалить');
  }

  static String? _detail(dynamic res) {
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['detail'] != null) return data['detail'].toString();
    } catch (_) {}
    return null;
  }
}
