import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/client_auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/app_cached_image.dart';
import '../models/service_order.dart';
import '../services/service_catalog_api.dart';
import 'client_service_order_detail_page.dart';
import 'create_service_request_page.dart';

class MyServiceRequestsPage extends StatefulWidget {
  const MyServiceRequestsPage({super.key});

  @override
  State<MyServiceRequestsPage> createState() => _MyServiceRequestsPageState();
}

class _MyServiceRequestsPageState extends State<MyServiceRequestsPage> {
  List<ServiceOrder> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token =
        Provider.of<ClientAuthProvider>(context, listen: false).accessToken;
    if (token == null || token.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final items = await ServiceCatalogApi.instance.myOrders(token);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(ServiceOrder order) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientServiceOrderDetailPage(order: order),
      ),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(settings.t('sr_my_requests'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateServiceRequestPage()),
          );
          if (created == true && mounted) _load();
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Пока нет заказов')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final o = _items[i];
                        final master = o.master;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openDetail(o),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.serviceTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${o.statusLabelRu} · ${o.priceClient.toStringAsFixed(0)} с',
                                  ),
                                  if (o.scheduleLabel.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(o.scheduleLabel),
                                  ],
                                  if (o.address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(o.address),
                                  ],
                                  if (o.isNew) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Ищем мастера в Истаравшане...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (master != null) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        ClipOval(
                                          child: SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: master.image.isNotEmpty
                                                ? AppCachedImage(
                                                    imagePath: master.image,
                                                    fit: BoxFit.cover,
                                                    shape: BoxShape.circle,
                                                    fallbackIcon: Icons.person,
                                                  )
                                                : const ColoredBox(
                                                    color: Color(0xFFE8E8E8),
                                                    child: Icon(
                                                      Icons.person,
                                                      size: 22,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                master.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                master.ratingLabel,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.amber.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
