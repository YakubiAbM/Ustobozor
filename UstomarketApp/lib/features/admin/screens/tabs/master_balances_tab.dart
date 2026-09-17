import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/admin_service_catalog_api.dart';
import '../../constants.dart';
import '../../widgets/admin_section_header.dart';

class MasterBalancesTab extends StatefulWidget {
  const MasterBalancesTab({super.key});

  @override
  State<MasterBalancesTab> createState() => _MasterBalancesTabState();
}

class _MasterBalancesTabState extends State<MasterBalancesTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await AdminServiceCatalogApi.balances();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _topup(Map<String, dynamic> row) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Пополнить: ${row['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(labelText: 'Сумма (сомони)'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Пополнить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount =
        double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    try {
      await AdminServiceCatalogApi.topup(
        masterId: int.parse('${row['master_id']}'),
        amount: amount,
        note: noteCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const AdminSectionHeader(title: 'Балансы мастеров'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final m = _items[i];
                        final bal = m['balance'];
                        final label = bal == null
                            ? 'нет кошелька'
                            : '${(bal as num).toStringAsFixed(2)} с';
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${m['name']}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text('${m['phone']}'),
                            trailing: Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                              ),
                            ),
                            onTap: () => _topup(m),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
