import 'package:flutter/material.dart';

import '../../api/admin_service_catalog_api.dart';
import '../../widgets/admin_section_header.dart';

class ServiceOrdersTab extends StatefulWidget {
  const ServiceOrdersTab({super.key});

  @override
  State<ServiceOrdersTab> createState() => _ServiceOrdersTabState();
}

class _ServiceOrdersTabState extends State<ServiceOrdersTab> {
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
      final items = await AdminServiceCatalogApi.orders();
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

  Future<void> _cancel(int id) async {
    try {
      await AdminServiceCatalogApi.patchOrder(id, status: 'CANCELLED');
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
          const AdminSectionHeader(title: 'Заказы услуг'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final o = _items[i];
                        final id = int.tryParse('${o['id']}') ?? 0;
                        return Card(
                          child: ListTile(
                            title: Text(
                              '#$id · ${o['service_title']}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${o['status']} · ${o['client_name']} ${o['client_phone']}\n'
                              '${o['address']}'
                              '${o['master_name'] != null && '${o['master_name']}'.isNotEmpty ? '\nМастер: ${o['master_name']}' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'cancel') _cancel(id);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('Отменить'),
                                ),
                              ],
                            ),
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
