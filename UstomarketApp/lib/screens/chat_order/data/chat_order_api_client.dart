import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../api_client.dart';
import '../../../constants.dart';
import '../models/chat_message_model.dart';
import '../models/invoice_models.dart';
import '../models/pick_models.dart';

/// Ответ от POST /chat/message или /chat/pick или /chat/action.
class ChatResponse {
  final String type; // invoice | pick | need_details | text | error
  final String? message;
  final InvoiceDraft? draft;
  final PickPayload? pickPayload;

  const ChatResponse({
    required this.type,
    this.message,
    this.draft,
    this.pickPayload,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    InvoiceDraft? draft;
    final draftJson = json['draft'] ?? json['invoice'];
    if (draftJson != null && draftJson is Map<String, dynamic>) {
      draft = InvoiceDraft.fromJson(draftJson);
    }
    PickPayload? pickPayload;
    if (json['options'] != null || json['item_index'] != null) {
      pickPayload = PickPayload(
        prompt: json['prompt'] as String? ?? '',
        itemIndex: json['item_index'] as int? ?? 0,
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => PickOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
    }
    return ChatResponse(
      type: json['type'] as String? ?? 'text',
      message: json['message'] as String?,
      draft: draft,
      pickPayload: pickPayload,
    );
  }
}

/// Ответ от POST /chat/submit.
class OrderCreatedResponse {
  final int orderId;
  final String status;

  const OrderCreatedResponse({required this.orderId, required this.status});

  factory OrderCreatedResponse.fromJson(Map<String, dynamic> json) {
    return OrderCreatedResponse(
      orderId: json['order_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'created',
    );
  }
}

class ChatOrderApiClient {
  static Future<String> createSession() async {
    final response = await apiPost('/chat/session', body: {});
    if (response.statusCode != 200) throw Exception('Session failed: ${response.statusCode}');
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return body['session_id'] as String? ?? '';
  }

  static Future<ChatResponse> sendMessage(String sessionId, String text) async {
    final response = await apiPost('/chat/message', body: {'session_id': sessionId, 'text': text});
    if (response.statusCode != 200) throw Exception('Send message failed: ${response.statusCode}');
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ChatResponse.fromJson(body);
  }

  static Future<ChatResponse> pick(String sessionId, int itemIndex, int productId) async {
    final response = await apiPost('/chat/pick', body: {
      'session_id': sessionId,
      'item_index': itemIndex,
      'product_id': productId,
    });
    if (response.statusCode != 200) throw Exception('Pick failed: ${response.statusCode}');
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ChatResponse.fromJson(body);
  }

  static Future<ChatResponse> action(String sessionId, String action, Map<String, dynamic> payload) async {
    final response = await apiPost('/chat/action', body: {'session_id': sessionId, 'action': action, 'payload': payload});
    if (response.statusCode != 200) throw Exception('Action failed: ${response.statusCode}');
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ChatResponse.fromJson(body);
  }

  /// Оформление заказа из чата. Те же поля, что и в корзине: client_name, client_phone, client_address, delivery, payment_type.
  static Future<OrderCreatedResponse> submit(
    String sessionId, {
    required String clientName,
    required String clientPhone,
    required String clientAddress,
    required bool isDelivery,
    required bool isCash,
    String? comment,
  }) async {
    final response = await apiPost('/chat/submit', body: {
      'session_id': sessionId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'client_address': isDelivery ? clientAddress : '',
      'payment_type': isCash ? 'cash' : 'card',
      'comment': (comment ?? '').trim().isEmpty ? null : comment!.trim(),
    });

    Map<String, dynamic>? body;
    try {
      final raw = utf8.decode(response.bodyBytes);
      if (raw.trim().isNotEmpty) {
        body = jsonDecode(raw) as Map<String, dynamic>?;
      }
    } catch (_) {
      body = null;
    }

    final isOk = response.statusCode == 200;
    final typeCreated = body?['type'] == 'created';
    final statusSuccess = body?['status'] == 'success';
    // order_id может прийти как int, num или String — парсим надёжно
    int parseOrderId() {
      final raw = body?['order_id'] ?? body?['id'];
      if (raw == null) return 0;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 0;
      return 0;
    }
    final hasOrderId = (body?['order_id'] ?? body?['id']) != null;

    if (isOk && (typeCreated || hasOrderId || statusSuccess)) {
      return OrderCreatedResponse(
        orderId: parseOrderId(),
        status: body?['status'] is String ? body!['status'] as String : 'created',
      );
    }

    Object? rawMsg = body?['detail'] ?? body?['message'] ?? body?['error'];
    String msg = (rawMsg is String ? rawMsg : rawMsg?.toString() ?? '').trim();
    if (msg.isEmpty) {
      if (!isOk) msg = 'Ошибка оформления заказа (код ${response.statusCode}). Попробуйте ещё раз.';
      else msg = 'Ошибка оформления заказа. Попробуйте ещё раз или обратитесь в поддержку.';
    }
    throw Exception(msg);
  }
}
