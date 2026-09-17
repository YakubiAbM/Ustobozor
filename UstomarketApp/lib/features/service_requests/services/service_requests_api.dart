import 'dart:convert';

import '../../../api_client.dart';
import '../models/service_request.dart';

class ServiceRequestsApi {
  ServiceRequestsApi._();
  static final instance = ServiceRequestsApi._();

  List<ServiceRequest> _parseList(httpBody) {
    final data = jsonDecode(httpBody is String ? httpBody : utf8.decode(httpBody));
    if (data is! Map) return [];
    final items = data['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => ServiceRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ServiceRequest> create({
    required String token,
    required String title,
    required String category,
    String description = '',
    String address = '',
    String city = '',
    double? budget,
    List<String> photosBase64 = const [],
  }) async {
    final r = await apiPostWithBearer(
      '/service-requests',
      token,
      body: {
        'title': title,
        'category': category,
        'description': description,
        'address': address,
        'city': city,
        'budget': budget,
        'photos_base64': photosBase64,
      },
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return ServiceRequest.fromJson(
      Map<String, dynamic>.from(data['request'] as Map),
    );
  }

  Future<List<ServiceRequest>> myRequests(String token) async {
    final r = await apiGetWithBearer('/service-requests/my', token);
    return _parseList(r.bodyBytes);
  }

  Future<List<ServiceRequest>> feed(String token) async {
    final r = await apiGetWithBearer('/service-requests/feed', token);
    return _parseList(r.bodyBytes);
  }

  Future<ServiceRequest> updateStatus({
    required String token,
    required int id,
    required String status,
  }) async {
    final r = await apiPostWithBearer(
      '/service-requests/$id/status',
      token,
      body: {'status': status},
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return ServiceRequest.fromJson(
      Map<String, dynamic>.from(data['request'] as Map),
    );
  }

  Future<ServiceRequest> respond({
    required String token,
    required int id,
    double? proposedPrice,
    String comment = '',
  }) async {
    final r = await apiPostWithBearer(
      '/service-requests/$id/respond',
      token,
      body: {
        'proposed_price': proposedPrice,
        'comment': comment,
      },
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return ServiceRequest.fromJson(
      Map<String, dynamic>.from(data['request'] as Map),
    );
  }

  Future<Map<String, dynamic>> convertToCrm({
    required String token,
    required int id,
  }) async {
    final r = await apiPostWithBearer(
      '/service-requests/$id/convert-to-crm',
      token,
    );
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return Map<String, dynamic>.from(data['crm'] as Map);
  }
}
