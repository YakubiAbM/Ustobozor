import 'package:flutter/material.dart';

import '../../api/admin_dashboard_api.dart';
import '../../constants.dart';
import '../../models/admin_order.dart';
import '../../widgets/admin_section_header.dart';
import '../invoice_screen.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<AdminOrder> _orders = [];
  bool _loading = true;
  String? _error;
  String? _filter;

  static const _filters = [
    (null, 'Все'),
    ('new', 'Новые'),
    ('processing', 'В работе'),
    ('completed', 'Выполнены'),
    ('canceled', 'Отменены'),
  ];

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
      final items = await AdminOrdersApi.fetch(status: _filter);
      if (!mounted) return;
      setState(() {
        _orders = items;
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

  Future<void> _changeStatus(AdminOrder order) async {
    final next = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Заказ #${order.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontSize: 16,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined, color: AppColors.accent),
                title: const Text('Накладная / печать', style: TextStyle(color: AppColors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => InvoiceScreen(orderId: order.id)),
                  );
                },
              ),
              const Divider(height: 1),
              for (final s in ['new', 'processing', 'completed', 'canceled'])
                ListTile(
                  title: Text(_statusLabel(s), style: const TextStyle(color: AppColors.text)),
                  trailing: order.status == s
                      ? const Icon(Icons.check, color: AppColors.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        );
      },
    );
    if (next == null || next == order.status) return;
    try {
      await AdminOrdersApi.updateStatus(order.id, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Статус: ${_statusLabel(next)}'),
          backgroundColor: AppColors.accent,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'processing':
        return 'В работе';
      case 'completed':
        return 'Выполнен';
      case 'canceled':
        return 'Отменён';
      default:
        return 'Новый';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'processing':
        return AppColors.orange;
      case 'completed':
        return AppColors.accent;
      case 'canceled':
        return const Color(0xFFEF4444);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdminSectionHeader(title: 'Заказы'),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final f = _filters[i];
                  final selected = _filter == f.$1;
                  return FilterChip(
                    label: Text(f.$2),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _filter = f.$1);
                      _load();
                    },
                    selectedColor: AppColors.accent.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.accent : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.cardElevated,
                    side: BorderSide.none,
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5))),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _orders.isEmpty
                      ? const Center(
                          child: Text(
                            'Заказов нет',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.accent,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _orders.length,
                            itemBuilder: (ctx, i) {
                              final o = _orders[i];
                              return _OrderCard(
                                order: o,
                                statusColor: _statusColor(o.status),
                                onTap: () => _changeStatus(o),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.onTap,
  });

  final AdminOrder order;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${o.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      o.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                o.clientName ?? 'Без имени',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              Text(o.clientPhone ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${o.totalPrice.toStringAsFixed(0)} смн',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  Text('${o.itemsCount} поз.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(o.createdAt ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              if (o.clientAddress != null && o.clientAddress!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  o.clientAddress!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              if (o.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    children: [
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _expanded ? 'Скрыть позиции' : 'Показать позиции',
                        style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (_expanded)
                  ...o.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name ?? '—',
                              style: const TextStyle(fontSize: 12, color: AppColors.text),
                            ),
                          ),
                          Text(
                            '${item.qty?.toStringAsFixed(0) ?? '1'} × ${item.price?.toStringAsFixed(0) ?? '0'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
