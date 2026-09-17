import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/master_auth_provider.dart';
import '../models/service_order.dart';
import '../services/service_catalog_api.dart';

class MasterBalanceHistoryPage extends StatefulWidget {
  const MasterBalanceHistoryPage({super.key});

  @override
  State<MasterBalanceHistoryPage> createState() =>
      _MasterBalanceHistoryPageState();
}

class _MasterBalanceHistoryPageState extends State<MasterBalanceHistoryPage> {
  double _balance = 0;
  List<BalanceTx> _txs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token =
        Provider.of<MasterAuthProvider>(context, listen: false).accessToken;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final bal = await ServiceCatalogApi.instance.balance(token);
      final txs = await ServiceCatalogApi.instance.balanceTransactions(token);
      if (!mounted) return;
      setState(() {
        _balance = bal;
        _txs = txs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История баланса')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: const Text('Текущий баланс'),
                      trailing: Text(
                        '${_balance.toStringAsFixed(2)} с',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_txs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: Text('Пока нет операций')),
                    )
                  else
                    ..._txs.map((t) {
                      final debit = t.amount < 0;
                      return ListTile(
                        leading: Icon(
                          debit ? Icons.remove_circle_outline : Icons.add_circle_outline,
                          color: debit ? Colors.redAccent : Colors.green,
                        ),
                        title: Text(
                          t.type == 'COMMISSION_DEBIT'
                              ? 'Комиссия${t.orderId != null ? ' · заказ #${t.orderId}' : ''}'
                              : 'Пополнение',
                        ),
                        subtitle: Text(
                          '${t.note.isNotEmpty ? '${t.note}\n' : ''}${t.createdAt}',
                        ),
                        trailing: Text(
                          '${t.amount > 0 ? '+' : ''}${t.amount.toStringAsFixed(2)} с',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: debit ? Colors.redAccent : Colors.green,
                          ),
                        ),
                        isThreeLine: t.note.isNotEmpty,
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
