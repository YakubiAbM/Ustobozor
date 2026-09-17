import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

@immutable
class ProjectChecklistItem {
  const ProjectChecklistItem({
    required this.id,
    required this.text,
    this.isDone = false,
  });

  final String id;
  final String text;
  final bool isDone;

  factory ProjectChecklistItem.fromMap(Map<dynamic, dynamic> map) {
    return ProjectChecklistItem(
      id: (map['id'] ?? const Uuid().v4()).toString(),
      text: (map['text'] ?? '').toString(),
      isDone: map['isDone'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'isDone': isDone,
      };

  ProjectChecklistItem copyWith({String? id, String? text, bool? isDone}) {
    return ProjectChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
    );
  }
}

@immutable
class ProjectPayment {
  const ProjectPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
  });

  final String id;
  final double amount;
  final DateTime date;
  final String note;

  factory ProjectPayment.fromMap(Map<dynamic, dynamic> map) {
    return ProjectPayment(
      id: (map['id'] ?? const Uuid().v4()).toString(),
      amount: ProjectModel._toDouble(map['amount']),
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      note: (map['note'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };
}

@immutable
class ProjectSketch {
  const ProjectSketch({
    required this.id,
    required this.imagePath,
    required this.createdAt,
  });

  final String id;
  final String imagePath;
  final DateTime createdAt;

  factory ProjectSketch.fromMap(Map<dynamic, dynamic> map) {
    return ProjectSketch(
      id: (map['id'] ?? const Uuid().v4()).toString(),
      imagePath: (map['imagePath'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
      };
}

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
    this.address = '',
    this.isCompleted = false,
    this.beforeVideo,
    this.afterVideo,
    this.checklist = const [],
    this.payments = const [],
    this.sketches = const [],
  });

  final String id;
  final String title;
  final String client;
  final String phone;
  final String address;
  final double income;
  final double receivedAmount;
  final DateTime date;
  final String note;
  final bool isCompleted;
  final List<String> beforeImages;
  final List<String> afterImages;
  final String? beforeVideo;
  final String? afterVideo;
  final List<ProjectChecklistItem> checklist;
  final List<ProjectPayment> payments;
  final List<ProjectSketch> sketches;

  bool get isFullyPaid => receivedAmount >= income && income > 0;
  bool get hasDebt => income > 0 && receivedAmount < income;
  double get debtAmount {
    final debt = income - receivedAmount;
    return debt > 0 ? debt : 0;
  }

  List<String> get images => [...beforeImages, ...afterImages];
  List<String> get galleryImages => images;

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

    final checklist = ((map['checklist'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ProjectChecklistItem.fromMap(e))
        .toList(growable: false);

    final payments = ((map['payments'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ProjectPayment.fromMap(e))
        .toList(growable: false);

    final sketches = ((map['sketches'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ProjectSketch.fromMap(e))
        .where((s) => s.imagePath.trim().isNotEmpty)
        .toList(growable: false);

    // Legacy: single note string → first checklist item if checklist empty
    final legacyNote = (map['note'] ?? '').toString().trim();
    final resolvedChecklist = checklist.isNotEmpty
        ? checklist
        : (legacyNote.isEmpty
            ? const <ProjectChecklistItem>[]
            : [
                ProjectChecklistItem(
                  id: 'legacy_note',
                  text: legacyNote,
                ),
              ]);

    return ProjectModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      client: (map['client'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      income: _toDouble(map['income']),
      receivedAmount: _toDouble(map['receivedAmount']),
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      note: legacyNote,
      isCompleted: map['isCompleted'] == true,
      beforeImages: beforeImages,
      afterImages: afterImages,
      beforeVideo: _toNullableString(map['beforeVideo']),
      afterVideo: _toNullableString(map['afterVideo']),
      checklist: resolvedChecklist,
      payments: payments,
      sketches: sketches,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'client': client,
      'phone': phone,
      'address': address,
      'income': income,
      'receivedAmount': receivedAmount,
      'date': date.toIso8601String(),
      'note': note,
      'isCompleted': isCompleted,
      'beforeImages': beforeImages,
      'afterImages': afterImages,
      'beforeVideo': beforeVideo,
      'afterVideo': afterVideo,
      'images': images,
      'checklist': checklist.map((e) => e.toMap()).toList(),
      'payments': payments.map((e) => e.toMap()).toList(),
      'sketches': sketches.map((e) => e.toMap()).toList(),
    };
  }

  ProjectModel copyWith({
    String? id,
    String? title,
    String? client,
    String? phone,
    String? address,
    double? income,
    double? receivedAmount,
    DateTime? date,
    String? note,
    bool? isCompleted,
    List<String>? beforeImages,
    List<String>? afterImages,
    String? beforeVideo,
    String? afterVideo,
    List<ProjectChecklistItem>? checklist,
    List<ProjectPayment>? payments,
    List<ProjectSketch>? sketches,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      client: client ?? this.client,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      income: income ?? this.income,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      date: date ?? this.date,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      beforeImages: beforeImages ?? this.beforeImages,
      afterImages: afterImages ?? this.afterImages,
      beforeVideo: beforeVideo ?? this.beforeVideo,
      afterVideo: afterVideo ?? this.afterVideo,
      checklist: checklist ?? this.checklist,
      payments: payments ?? this.payments,
      sketches: sketches ?? this.sketches,
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
