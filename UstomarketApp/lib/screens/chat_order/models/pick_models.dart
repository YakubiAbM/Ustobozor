/// Вариант выбора при уточнении позиции.
class PickOption {
  final int id;
  final String name;
  final double price;
  final String unit;
  final String image;

  const PickOption({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.image,
  });

  factory PickOption.fromJson(Map<String, dynamic> json) {
    return PickOption(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'шт',
      image: json['image'] as String? ?? '',
    );
  }
}

/// Payload для выбора варианта (уточнение позиции).
class PickPayload {
  final String prompt;
  final int itemIndex;
  final List<PickOption> options;

  const PickPayload({
    required this.prompt,
    required this.itemIndex,
    required this.options,
  });

  factory PickPayload.fromJson(Map<String, dynamic> json) {
    final opts = json['options'] as List<dynamic>? ?? [];
    return PickPayload(
      prompt: json['prompt'] as String? ?? '',
      itemIndex: json['item_index'] as int? ?? 0,
      options: opts.map((e) => PickOption.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
