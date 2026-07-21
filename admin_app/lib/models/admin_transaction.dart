class AdminTransaction {
  AdminTransaction({
    required this.id,
    this.masterId,
    this.masterName,
    required this.amount,
    this.createdAt,
  });

  final int id;
  final int? masterId;
  final String? masterName;
  final double amount;
  final String? createdAt;

  factory AdminTransaction.fromJson(Map<String, dynamic> json) {
    return AdminTransaction(
      id: (json['id'] as num).toInt(),
      masterId: (json['master_id'] as num?)?.toInt(),
      masterName: json['master_name']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }
}
