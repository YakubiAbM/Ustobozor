import 'package:flutter/material.dart';

import '../../api/admin_service_catalog_api.dart';
import '../../constants.dart';
import '../../widgets/admin_section_header.dart';

class ServiceCatalogTab extends StatefulWidget {
  const ServiceCatalogTab({super.key});

  @override
  State<ServiceCatalogTab> createState() => _ServiceCatalogTabState();
}

class _ServiceCatalogTabState extends State<ServiceCatalogTab> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await AdminServiceCatalogApi.categories();
      final items = await AdminServiceCatalogApi.list(q: _search.text.trim());
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final titleCtrl = TextEditingController(text: '${row?['title'] ?? ''}');
    final priceCtrl =
        TextEditingController(text: '${row?['price_client'] ?? ''}');
    int categoryId = int.tryParse('${row?['category_id']}') ??
        (_categories.isNotEmpty
            ? int.tryParse('${_categories.first['id']}') ?? 0
            : 0);
    bool active = row == null
        ? true
        : (row['is_active'] == true || row['is_active'] == 1);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(row == null ? 'Новая услуга' : 'Редактировать'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: categoryId == 0 ? null : categoryId,
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: int.tryParse('${c['id']}'),
                          child: Text('${c['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => categoryId = v ?? 0),
                  decoration: const InputDecoration(labelText: 'Категория'),
                ),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Цена клиенту (с)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Включено'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await AdminServiceCatalogApi.upsert(
        id: row == null ? null : int.tryParse('${row['id']}'),
        categoryId: categoryId,
        title: titleCtrl.text.trim(),
        priceClient: double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0,
        commissionFee: 0,
        isActive: active,
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
          const AdminSectionHeader(title: 'Услуги'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Поиск…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_circle, color: AppColors.accent),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final s = _items[i];
                        final active =
                            s['is_active'] == true || s['is_active'] == 1;
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${s['title']}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${s['category_name']} · '
                              '${s['price_client']} с'
                              '${active ? '' : ' · выкл'}',
                            ),
                            onTap: () => _edit(s),
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
