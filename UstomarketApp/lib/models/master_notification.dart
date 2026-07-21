/// Уведомление для мастера: акции (promo), начисление/списание баллов (points_added, points_spent), оплата долга (debt).
class MasterNotification {
  final int id;
  final int masterId;
  final String type; // promo, points_added, points_spent, debt
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final String createdAt;
  final String? readAt;

  MasterNotification({
    required this.id,
    required this.masterId,
    required this.type,
    required this.title,
    required this.body,
    this.payload = const {},
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  factory MasterNotification.fromJson(Map<String, dynamic> json) {
    return MasterNotification(
      id: (json['id'] is int) ? json['id'] as int : (json['id'] as num).toInt(),
      masterId: (json['master_id'] is int) ? json['master_id'] as int : (json['master_id'] as num).toInt(),
      type: json['type'] as String? ?? 'promo',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload'] as Map) : {},
      createdAt: json['created_at'] as String? ?? '',
      readAt: json['read_at'] as String?,
    );
  }
}
