import 'dart:convert';

import '../models/admin_dashboard.dart';
import '../models/admin_master.dart';
import '../models/admin_order.dart';
import '../models/order_invoice.dart';
import '../models/admin_transaction.dart';
import 'admin_http.dart';

class AdminDashboardApi {
  static Future<AdminDashboard> fetch() async {
    final res = await AdminHttp.get('/admin/api/dashboard');
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('Нет доступа. Войдите снова.');
    }
    if (res.statusCode != 200) {
      throw Exception('Ошибка дашборда: ${res.statusCode}');
    }
    return AdminDashboard.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

class AdminOrdersApi {
  static Future<List<AdminOrder>> fetch({String? status}) async {
    final res = await AdminHttp.get(
      '/admin/api/orders',
      query: status != null && status.isNotEmpty ? {'status': status} : null,
    );
    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки заказов: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return [];
    return data
        .map((e) => AdminOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AdminOrder> updateStatus(int orderId, String newStatus) async {
    final res = await AdminHttp.post(
      '/admin/api/orders/$orderId/status',
      body: {'new_status': newStatus},
    );
    if (res.statusCode != 200) {
      throw Exception('Не удалось обновить статус');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return AdminOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  static Future<OrderInvoice> fetchInvoice(int orderId) async {
    final res = await AdminHttp.get('/admin/api/orders/$orderId/invoice');
    if (res.statusCode != 200) {
      throw Exception('Не удалось загрузить накладную');
    }
    return OrderInvoice.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

class AdminMastersApi {
  static Future<List<AdminMaster>> fetch({
    String? search,
    String? moderationStatus,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (moderationStatus != null && moderationStatus.trim().isNotEmpty) {
      query['moderation_status'] = moderationStatus.trim();
    }
    final res = await AdminHttp.get(
      '/admin/api/masters',
      query: query.isEmpty ? null : query,
    );
    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки мастеров: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return [];
    return data
        .map((e) => AdminMaster.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<String> resetPassword(int masterId) async {
    final res = await AdminHttp.post('/admin/api/masters/$masterId/reset-password');
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('Нет доступа. Войдите снова.');
    }
    if (res.statusCode != 200) {
      throw Exception('Не удалось сбросить пароль: ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return data['message']?.toString() ??
        'Пароль сброшен. Мастер может задать новый в приложении.';
  }
}

class AdminCashierApi {
  static Future<AdminCashierSummary> summary() async {
    final res = await AdminHttp.get('/admin/api/cashier/summary');
    if (res.statusCode != 200) {
      throw Exception('Ошибка кассы: ${res.statusCode}');
    }
    return AdminCashierSummary.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<AdminPointsResult> addPoints(String identifier, int amount) async {
    final res = await AdminHttp.post(
      '/admin/api/cashier/points/add',
      body: {'identifier': identifier, 'amount': amount},
    );
    if (res.statusCode != 200) {
      throw Exception('Ошибка начисления');
    }
    return AdminPointsResult.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<AdminPointsResult> spendPoints(String identifier, int amount) async {
    final res = await AdminHttp.post(
      '/admin/api/cashier/points/spend',
      body: {'identifier': identifier, 'amount': amount},
    );
    if (res.statusCode != 200) {
      throw Exception('Ошибка списания');
    }
    return AdminPointsResult.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<List<AdminDebtor>> fetchDebtors() async {
    final res = await AdminHttp.get('/admin/api/cashier/debtors');
    if (res.statusCode != 200) {
      throw Exception('Ошибка загрузки должников');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return [];
    return data
        .map((e) => AdminDebtor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AdminDebtResult> addDebt(String identifier, double amount) async {
    final res = await AdminHttp.post(
      '/admin/api/cashier/debt/add',
      body: {'identifier': identifier, 'amount': amount},
    );
    if (res.statusCode != 200) {
      throw Exception('Ошибка оформления долга');
    }
    return AdminDebtResult.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<AdminDebtResult> payDebt(String identifier, double amount) async {
    final res = await AdminHttp.post(
      '/admin/api/cashier/debt/pay',
      body: {'identifier': identifier, 'amount': amount},
    );
    if (res.statusCode != 200) {
      throw Exception('Ошибка оплаты долга');
    }
    return AdminDebtResult.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Future<String> sendPromo(String title, String body) async {
    final res = await AdminHttp.post(
      '/admin/api/cashier/promo',
      body: {'title': title, 'body': body},
    );
    if (res.statusCode != 200) {
      throw Exception('Ошибка рассылки');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return data['message']?.toString() ?? 'Отправлено';
  }
}

class AdminDebtor {
  AdminDebtor({
    required this.id,
    this.name,
    this.phone,
    required this.debt,
    required this.points,
  });

  final int id;
  final String? name;
  final String? phone;
  final double debt;
  final int points;

  factory AdminDebtor.fromJson(Map<String, dynamic> json) {
    return AdminDebtor(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminDebtResult {
  AdminDebtResult({
    required this.ok,
    required this.message,
    this.debt,
  });

  final bool ok;
  final String message;
  final double? debt;

  factory AdminDebtResult.fromJson(Map<String, dynamic> json) {
    return AdminDebtResult(
      ok: json['ok'] == true,
      message: json['message']?.toString() ?? '',
      debt: (json['debt'] as num?)?.toDouble(),
    );
  }
}

class AdminCashierSummary {
  AdminCashierSummary({
    required this.operationsToday,
    required this.revenueToday,
    required this.recent,
  });

  final int operationsToday;
  final double revenueToday;
  final List<AdminTransaction> recent;

  factory AdminCashierSummary.fromJson(Map<String, dynamic> json) {
    final recentRaw = json['recent'];
    return AdminCashierSummary(
      operationsToday: (json['operations_today'] as num?)?.toInt() ?? 0,
      revenueToday: (json['revenue_today'] as num?)?.toDouble() ?? 0,
      recent: recentRaw is List
          ? recentRaw
              .map((e) => AdminTransaction.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

class AdminPointsResult {
  AdminPointsResult({
    required this.ok,
    required this.message,
    this.masterId,
    this.masterName,
    this.points,
  });

  final bool ok;
  final String message;
  final int? masterId;
  final String? masterName;
  final int? points;

  factory AdminPointsResult.fromJson(Map<String, dynamic> json) {
    return AdminPointsResult(
      ok: json['ok'] == true,
      message: json['message']?.toString() ?? '',
      masterId: (json['master_id'] as num?)?.toInt(),
      masterName: json['master_name']?.toString(),
      points: (json['points'] as num?)?.toInt(),
    );
  }
}
