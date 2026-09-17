import 'package:flutter/material.dart';

import '../../api/admin_dashboard_api.dart';
import '../../constants.dart';
import '../../models/admin_dashboard.dart';
import '../../models/admin_order.dart';
import '../../widgets/admin_section_header.dart';
import '../../widgets/admin_stat_card.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  AdminDashboard? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminDashboardApi.fetch();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const AdminSectionHeader(title: 'Дашборд'),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5))),
                )
              else if (_data != null)
                _DashboardBody(data: _data!),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final AdminDashboard data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Добро пожаловать',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ustomarket Admin',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              AdminStatCard(
                label: 'Новые заказы',
                value: '${data.newOrdersCount}',
                icon: Icons.receipt_long_outlined,
                trend: data.ordersTodayCount > 0 ? 'сегодня ${data.ordersTodayCount}' : null,
              ),
              AdminStatCard(
                label: 'Товары',
                value: '${data.productsCount}',
                icon: Icons.inventory_2_outlined,
                accentColor: AppColors.orange,
              ),
              AdminStatCard(
                label: 'Мастера',
                value: '${data.totalMasters}',
                icon: Icons.engineering_outlined,
              ),
              AdminStatCard(
                label: 'Выручка (выполн.)',
                value: '${data.onlineRevenue.toStringAsFixed(0)} смн',
                icon: Icons.payments_outlined,
                trend: 'касса ${data.offlineRevenueToday.toStringAsFixed(0)}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Последние заказы',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          if (data.recentOrders.isEmpty)
            const Text('Заказов пока нет', style: TextStyle(color: AppColors.textSecondary))
          else
            ...data.recentOrders.map((o) => _RecentOrderTile(order: o)),
          const SizedBox(height: 20),
          if (kMasterPointsEnabled) ...[
            const Text(
              'Последние операции кассы',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            if (data.recentTransactions.isEmpty)
              const Text('Операций пока нет', style: TextStyle(color: AppColors.textSecondary))
            else
              ...data.recentTransactions.map(
                (t) => _RecentTxTile(
                  name: t.masterName ?? '—',
                  amount: t.amount,
                  date: t.createdAt ?? '',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.id} · ${order.clientName ?? 'Клиент'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${order.totalPrice.toStringAsFixed(0)} смн · ${order.statusLabel}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            order.createdAt?.split(' ').first ?? '',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RecentTxTile extends StatelessWidget {
  const _RecentTxTile({
    required this.name,
    required this.amount,
    required this.date,
  });

  final String name;
  final double amount;
  final String date;

  @override
  Widget build(BuildContext context) {
    final sign = amount >= 0 ? '+' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(color: AppColors.text)),
          ),
          Text(
            '$sign${amount.toStringAsFixed(0)} балл',
            style: TextStyle(
              color: amount >= 0 ? AppColors.accent : AppColors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
