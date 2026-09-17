import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants.dart';
import '../../../providers/master_auth_provider.dart';
import '../../../providers/navigation_provider.dart';
import '../../../providers/settings_provider.dart';
import '../models/service_order.dart';
import '../services/navigation_launcher.dart';
import '../services/service_catalog_api.dart';

/// Лента заказов из каталога (без списания комиссии).
class ServiceRequestsFeedPage extends StatefulWidget {
  const ServiceRequestsFeedPage({super.key});

  @override
  State<ServiceRequestsFeedPage> createState() =>
      _ServiceRequestsFeedPageState();
}

class _ServiceRequestsFeedPageState extends State<ServiceRequestsFeedPage> {
  List<ServiceOrder> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token =
        Provider.of<MasterAuthProvider>(context, listen: false).accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }
    try {
      final items = await ServiceCatalogApi.instance.feed(token);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(ServiceOrder order) async {
    final token =
        Provider.of<MasterAuthProvider>(context, listen: false).accessToken;
    if (token == null) return;
    try {
      final res = await ServiceCatalogApi.instance.accept(
        masterToken: token,
        orderId: order.id,
      );
      if (!mounted) return;
      final accepted = ServiceOrder.fromJson(
        Map<String, dynamic>.from(res['order'] as Map),
      );

      // Остаёмся на вкладке ленты мастера и обновляем список.
      context.read<NavigationProvider>().setIndex(NavigationProvider.tabMasters);

      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => _ContactsSheet(order: accepted),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ принят'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final master = Provider.of<MasterAuthProvider>(context);
    final loggedIn = master.accessToken != null && master.accessToken!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('sr_feed_title')),
        centerTitle: true,
      ),
      body: !loggedIn
          ? Center(child: Text(settings.t('sr_need_master_login')))
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(child: Text(settings.t('sr_feed_empty'))),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Заказ #${item.id}: ${item.serviceTitle}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (item.address.isNotEmpty)
                                      Text('📍 ${item.address}'),
                                    if (item.scheduleLabel.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('🗓 ${item.scheduleLabel}'),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      '💵 Оплата от клиента: ${item.priceClient.toStringAsFixed(0)} сомони',
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => _accept(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accent,
                                          foregroundColor:
                                              AppColors.accentContrastText,
                                        ),
                                        child: const Text(
                                          'Принять заказ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _ContactsSheet extends StatelessWidget {
  const _ContactsSheet({required this.order});
  final ServiceOrder order;

  Future<void> _openRoute(BuildContext context) async {
    final lat = order.latitude;
    final lng = order.longitude;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Координаты не указаны')),
      );
      return;
    }
    final ok = await openRouteNavigator(latitude: lat, longitude: lng);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть навигатор')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = order.clientPhone.replaceAll(RegExp(r'[^\d+]'), '');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Контакты заказчика',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(order.clientName.isEmpty ? 'Клиент' : order.clientName),
            Text(order.clientPhone, style: const TextStyle(fontSize: 18)),
            if (order.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ориентир: ${order.address}'),
            ],
            if (order.hasPreciseLocation) ...[
              const SizedBox(height: 4),
              Text(
                'Координаты: ${order.latitude!.toStringAsFixed(5)}, '
                '${order.longitude!.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
            if (order.scheduleLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Когда: ${order.scheduleLabel}'),
            ],
            const SizedBox(height: 16),
            if (order.hasPreciseLocation)
              ElevatedButton.icon(
                onPressed: () => _openRoute(context),
                icon: const Icon(Icons.navigation),
                label: const Text('Маршрут на карте'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentContrastText,
                ),
              ),
            if (order.hasPreciseLocation) const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: phone.isEmpty
                  ? null
                  : () => launchUrl(Uri.parse('tel:$phone')),
              icon: const Icon(Icons.phone),
              label: const Text('Позвонить'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: phone.isEmpty
                  ? null
                  : () {
                      final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
                      launchUrl(Uri.parse('https://wa.me/$digits'));
                    },
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}
