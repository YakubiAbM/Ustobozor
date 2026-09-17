import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../models/master.dart';
import '../../../providers/client_auth_provider.dart';
import '../../../screens/master_detail_screen.dart';
import '../../../utils/app_page_route.dart';
import '../../../utils/phone_launcher.dart';
import '../../../widgets/app_cached_image.dart';
import '../models/service_order.dart';
import '../services/service_catalog_api.dart';
import 'leave_review_page.dart';

class ClientServiceOrderDetailPage extends StatefulWidget {
  const ClientServiceOrderDetailPage({super.key, required this.order});

  final ServiceOrder order;

  @override
  State<ClientServiceOrderDetailPage> createState() =>
      _ClientServiceOrderDetailPageState();
}

class _ClientServiceOrderDetailPageState
    extends State<ClientServiceOrderDetailPage> {
  late ServiceOrder _order;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _openMasterProfile() async {
    final m = _order.master;
    if (m == null) return;
    // Тот же экран, что с главного меню: полный профиль подгрузится по id.
    final master = Master(
      id: m.id,
      name: m.name,
      phone: m.phone,
      category: m.specialization,
      description: m.description,
      image: m.image,
      rating: m.rating,
      reviewsCount: m.reviewsCount,
      city: m.city,
      experience: m.experience,
    );
    await Navigator.push(
      context,
      AppPageRoute.deferred((_) => MasterDetailScreen(master: master)),
    );
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить заказ?'),
        content: const Text('Заказ будет отменён и исчезнет из ленты мастеров.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final token = context.read<ClientAuthProvider>().accessToken;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      final updated = await ServiceCatalogApi.instance.updateStatus(
        clientToken: token,
        orderId: _order.id,
        status: 'CANCELLED',
      );
      if (!mounted) return;
      setState(() => _order = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ отменён')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeAndReview() async {
    final reviewed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LeaveReviewPage(orderId: _order.id),
      ),
    );
    if (reviewed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = _order.master;
    final canAct = !_busy && !_order.isCancelled && !_order.isCompleted;

    return Scaffold(
      appBar: AppBar(title: Text('Заказ #${_order.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _order.serviceTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${_order.priceClient.toStringAsFixed(0)} сомони · ${_order.statusLabelRu}',
            style: const TextStyle(fontSize: 15),
          ),
          if (_order.scheduleLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('🗓 ${_order.scheduleLabel}'),
          ],
          if (_order.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('📍 ${_order.address}'),
          ],
          if (_order.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_order.comment),
          ],
          const SizedBox(height: 20),
          if (_order.isNew)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ищем мастера в Истаравшане...',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          if (master != null) ...[
            const Text(
              'Ваш мастер',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: master.image.isNotEmpty
                        ? AppCachedImage(
                            imagePath: master.image,
                            fit: BoxFit.cover,
                            shape: BoxShape.circle,
                            fallbackIcon: Icons.person,
                          )
                        : const ColoredBox(
                            color: Color(0xFFE8E8E8),
                            child: Icon(Icons.person, size: 32),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        master.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (master.specialization.isNotEmpty)
                        Text(master.specialization),
                      Text(
                        master.ratingLabel,
                        style: TextStyle(color: Colors.amber.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _openMasterProfile,
              child: const Text('Перейти в профиль'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: master.phone.isEmpty
                        ? null
                        : () => launchPhoneCall(context, master.phone),
                    icon: const Icon(Icons.phone),
                    label: const Text('Позвонить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentContrastText,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: master.phone.isEmpty
                        ? null
                        : () => launchWhatsApp(context, master.phone),
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          if ((_order.isInProgress || _order.isCompleted) &&
              !_order.hasReview) ...[
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: canAct || _order.isCompleted
                    ? _completeAndReview
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentContrastText,
                ),
                child: const Text(
                  'Завершить заказ и оценить',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_order.hasReview)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Отзыв уже опубликован'),
            ),
          if (!_order.isCancelled && !_order.isCompleted)
            OutlinedButton(
              onPressed: _busy ? null : _cancel,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Отменить заказ'),
            ),
        ],
      ),
    );
  }
}
