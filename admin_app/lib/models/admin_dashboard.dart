import 'admin_order.dart';
import 'admin_transaction.dart';

class AdminDashboard {
  AdminDashboard({
    required this.newOrdersCount,
    required this.ordersTodayCount,
    required this.onlineRevenue,
    required this.offlineRevenueToday,
    required this.totalMasters,
    required this.productsCount,
    required this.recentOrders,
    required this.recentTransactions,
  });

  final int newOrdersCount;
  final int ordersTodayCount;
  final double onlineRevenue;
  final double offlineRevenueToday;
  final int totalMasters;
  final int productsCount;
  final List<AdminOrder> recentOrders;
  final List<AdminTransaction> recentTransactions;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(dynamic raw, T Function(Map<String, dynamic>) fn) {
      if (raw is! List) return [];
      return raw.map((e) => fn(e as Map<String, dynamic>)).toList();
    }

    return AdminDashboard(
      newOrdersCount: (json['new_orders_count'] as num?)?.toInt() ?? 0,
      ordersTodayCount: (json['orders_today_count'] as num?)?.toInt() ?? 0,
      onlineRevenue: (json['online_revenue'] as num?)?.toDouble() ?? 0,
      offlineRevenueToday: (json['offline_revenue_today'] as num?)?.toDouble() ?? 0,
      totalMasters: (json['total_masters'] as num?)?.toInt() ?? 0,
      productsCount: (json['products_count'] as num?)?.toInt() ?? 0,
      recentOrders: mapList(json['recent_orders'], AdminOrder.fromJson),
      recentTransactions: mapList(json['recent_transactions'], AdminTransaction.fromJson),
    );
  }
}
