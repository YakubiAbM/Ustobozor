import 'dart:convert';

import 'admin_http.dart';

class AdminServiceCatalogApi {
  static Future<List<Map<String, dynamic>>> categories() async {
    final r = await AdminHttp.get('/admin/api/service-categories');
    _ensureOk(r.statusCode);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> list({String? q}) async {
    final r = await AdminHttp.get(
      '/admin/api/service-catalog',
      query: q == null || q.isEmpty ? null : {'q': q},
    );
    _ensureOk(r.statusCode);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> upsert({
    int? id,
    required int categoryId,
    required String title,
    required double priceClient,
    required double commissionFee,
    required bool isActive,
  }) async {
    final body = {
      'category_id': categoryId,
      'title': title,
      'price_client': priceClient,
      'commission_fee': commissionFee,
      'is_active': isActive,
    };
    final r = id == null
        ? await AdminHttp.post('/admin/api/service-catalog', body: body)
        : await AdminHttp.put('/admin/api/service-catalog/$id', body: body);
    _ensureOk(r.statusCode);
  }

  static Future<List<Map<String, dynamic>>> orders({String? status}) async {
    final r = await AdminHttp.get(
      '/admin/api/service-orders',
      query: status == null ? null : {'status': status},
    );
    _ensureOk(r.statusCode);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> patchOrder(
    int id, {
    String? status,
    int? masterId,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (masterId != null) body['master_id'] = masterId;
    final r = await AdminHttp.patch(
      '/admin/api/service-orders/$id',
      body: body,
    );
    _ensureOk(r.statusCode);
  }

  static Future<List<Map<String, dynamic>>> balances() async {
    final r = await AdminHttp.get('/admin/api/master-balances');
    _ensureOk(r.statusCode);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<double> topup({
    required int masterId,
    required double amount,
    String note = '',
  }) async {
    final r = await AdminHttp.post(
      '/admin/api/master-balances/topup',
      body: {
        'master_id': masterId,
        'amount': amount,
        'note': note,
      },
    );
    _ensureOk(r.statusCode);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return double.tryParse('${(data as Map)['balance']}') ?? 0;
  }

  static void _ensureOk(int code) {
    if (code < 200 || code >= 300) {
      throw Exception('Ошибка сервера ($code)');
    }
  }
}
