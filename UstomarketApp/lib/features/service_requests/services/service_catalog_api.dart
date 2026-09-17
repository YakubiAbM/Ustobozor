import 'dart:convert';

import '../../../api_client.dart';
import '../models/service_order.dart';

class ServiceCatalogApi {
  ServiceCatalogApi._();
  static final instance = ServiceCatalogApi._();

  Future<List<ServiceCategory>> categories() async {
    final r = await apiGet('/service-catalog/categories');
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => ServiceCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CatalogService>> services({int? categoryId, String? q}) async {
    final query = <String, String>{};
    if (categoryId != null) query['category_id'] = '$categoryId';
    if (q != null && q.trim().isNotEmpty) query['q'] = q.trim();
    final r = await apiGet('/service-catalog', queryParameters: query);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => CatalogService.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ServiceOrder> createOrder({
    required String clientToken,
    required int serviceId,
    required String address,
    required String scheduledDate,
    required String scheduledTime,
    required double latitude,
    required double longitude,
    String comment = '',
    List<String> photosBase64 = const [],
  }) async {
    final r = await apiPostWithBearer(
      '/service-orders',
      clientToken,
      body: {
        'service_id': serviceId,
        'address': address,
        'address_text': address,
        'comment': comment,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'latitude': latitude,
        'longitude': longitude,
        'photos_base64': photosBase64,
      },
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return ServiceOrder.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<ServiceOrder>> myOrders(String clientToken) async {
    final r = await apiGetWithBearer('/service-orders/my', clientToken);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => ServiceOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ServiceOrder>> feed(String masterToken) async {
    final r = await apiGetWithBearer('/service-orders/feed', masterToken);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => ServiceOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> accept({
    required String masterToken,
    required int orderId,
  }) async {
    final r = await apiPostWithBearer(
      '/service-orders/$orderId/accept',
      masterToken,
      body: {},
      acceptedStatusCodes: {409},
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      final detail = data is Map ? data['detail'] : data;
      throw Exception(detail?.toString() ?? 'Ошибка');
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<double> balance(String masterToken) async {
    final r = await apiGetWithBearer('/masters/me/balance', masterToken);
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is Map) {
      return double.tryParse('${data['balance']}') ?? 0;
    }
    return 0;
  }

  Future<List<BalanceTx>> balanceTransactions(String masterToken) async {
    final r = await apiGetWithBearer(
      '/masters/me/balance/transactions',
      masterToken,
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => BalanceTx.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ServiceOrder> updateStatus({
    required String clientToken,
    required int orderId,
    required String status,
  }) async {
    final r = await apiPostWithBearer(
      '/service-orders/$orderId/status',
      clientToken,
      body: {'status': status},
      acceptedStatusCodes: {409},
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      final detail = data is Map ? data['detail'] : data;
      throw Exception(detail?.toString() ?? 'Ошибка');
    }
    return ServiceOrder.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ServiceOrder> submitReview({
    required String clientToken,
    required int orderId,
    required int rating,
    String comment = '',
    List<String> photosBase64 = const [],
  }) async {
    final r = await apiPostWithBearer(
      '/service-orders/$orderId/review',
      clientToken,
      body: {
        'rating': rating,
        'comment': comment,
        'photos_base64': photosBase64,
      },
      acceptedStatusCodes: {409},
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      final detail = data is Map ? data['detail'] : data;
      throw Exception(detail?.toString() ?? 'Ошибка');
    }
    final order = data is Map ? data['order'] : null;
    if (order is Map) {
      return ServiceOrder.fromJson(Map<String, dynamic>.from(order));
    }
    throw Exception('Некорректный ответ сервера');
  }

  Future<List<MasterReview>> masterReviews(int masterId) async {
    final r = await apiGet('/masters/$masterId/reviews');
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => MasterReview.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
