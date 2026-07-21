class AdminSession {
  AdminSession({
    required this.name,
    this.phone,
    required this.isSuperadmin,
    required this.permissions,
  });

  final String name;
  final String? phone;
  final bool isSuperadmin;
  final Set<String> permissions;

  bool can(String scope) => isSuperadmin || permissions.contains(scope);

  bool get canDashboard => can('dashboard');
  bool get canProducts => can('products');
  bool get canOrders => can('orders');
  bool get canMasters => can('masters');
  bool get canCashier => can('cashier');

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    final permsRaw = json['permissions'];
    final perms = <String>{};
    if (permsRaw is List) {
      for (final p in permsRaw) {
        final s = p?.toString();
        if (s != null && s.isNotEmpty) perms.add(s);
      }
    }
    return AdminSession(
      name: json['name']?.toString() ?? 'Админ',
      phone: json['phone']?.toString(),
      isSuperadmin: json['is_superadmin'] == true,
      permissions: perms,
    );
  }
}
