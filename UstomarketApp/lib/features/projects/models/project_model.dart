import 'package:flutter/foundation.dart';

@immutable
class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.title,
    required this.client,
    required this.phone,
    required this.income,
    required this.receivedAmount,
    required this.date,
    required this.note,
    required this.beforeImages,
    required this.afterImages,
    this.beforeVideo,
    this.afterVideo,
  });

  final String id;
  final String title;
  final String client;
  final String phone;
  final double income;
  final double receivedAmount;
  final DateTime date;
  final String note;
  final List<String> beforeImages;
  final List<String> afterImages;
  final String? beforeVideo;
  final String? afterVideo;

  bool get isFullyPaid => receivedAmount >= income;
  bool get hasDebt => receivedAmount < income;
  double get debtAmount {
    final debt = income - receivedAmount;
    return debt > 0 ? debt : 0;
  }

  List<String> get images => [...beforeImages, ...afterImages];

  factory ProjectModel.fromMap(Map<dynamic, dynamic> map) {
    final legacyImages = ((map['images'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    final beforeImages = ((map['beforeImages'] as List?) ?? legacyImages)
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    final afterImages = ((map['afterImages'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);

    return ProjectModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      client: (map['client'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      income: _toDouble(map['income']),
      receivedAmount: _toDouble(map['receivedAmount']),
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      note: (map['note'] ?? '').toString(),
      beforeImages: beforeImages,
      afterImages: afterImages,
      beforeVideo: _toNullableString(map['beforeVideo']),
      afterVideo: _toNullableString(map['afterVideo']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'client': client,
      'phone': phone,
      'income': income,
      'receivedAmount': receivedAmount,
      'date': date.toIso8601String(),
      'note': note,
      'beforeImages': beforeImages,
      'afterImages': afterImages,
      'beforeVideo': beforeVideo,
      'afterVideo': afterVideo,
      'images': images,
    };
  }

  ProjectModel copyWith({
    String? id,
    String? title,
    String? client,
    String? phone,
    double? income,
    double? receivedAmount,
    DateTime? date,
    String? note,
    List<String>? beforeImages,
    List<String>? afterImages,
    String? beforeVideo,
    String? afterVideo,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      client: client ?? this.client,
      phone: phone ?? this.phone,
      income: income ?? this.income,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      date: date ?? this.date,
      note: note ?? this.note,
      beforeImages: beforeImages ?? this.beforeImages,
      afterImages: afterImages ?? this.afterImages,
      beforeVideo: beforeVideo ?? this.beforeVideo,
      afterVideo: afterVideo ?? this.afterVideo,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _toNullableString(dynamic value) {
    final stringValue = value?.toString().trim() ?? '';
    return stringValue.isEmpty ? null : stringValue;
  }
}
