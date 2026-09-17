import 'package:flutter/material.dart';

import '../../api/admin_dashboard_api.dart';
import '../../api/admin_masters_api.dart';
import '../../constants.dart';
import 'master_edit_screen.dart';

class MasterDetailScreen extends StatefulWidget {
  const MasterDetailScreen({super.key, required this.masterId});

  final int masterId;

  @override
  State<MasterDetailScreen> createState() => _MasterDetailScreenState();
}

class _MasterDetailScreenState extends State<MasterDetailScreen> {
  AdminMasterDetail? _detail;
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
      final d = await AdminMastersCrudApi.fetchDetail(widget.masterId);
      if (!mounted) return;
      setState(() {
        _detail = d;
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

  Future<void> _resetPassword() async {
    final name = _detail?.name ?? 'мастера';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Сброс пароля', style: TextStyle(color: AppColors.text)),
        content: Text(
          'Сбросить пароль для «$name»?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final msg = await AdminMastersApi.resetPassword(widget.masterId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.accent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MasterEditScreen(masterId: widget.masterId)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Удалить мастера?', style: TextStyle(color: AppColors.text)),
        content: const Text('Действие необратимо.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AdminMastersCrudApi.delete(widget.masterId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _approve() async {
    try {
      final d = await AdminMastersCrudApi.approve(widget.masterId);
      if (!mounted) return;
      setState(() => _detail = d);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Объявление одобрено'), backgroundColor: AppColors.accent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _reject() async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Отклонить объявление?', style: TextStyle(color: AppColors.text)),
        content: TextField(
          controller: noteCtrl,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            hintText: 'Причина (необязательно)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final d = await AdminMastersCrudApi.reject(
        widget.masterId,
        note: noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _detail = d);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Объявление отклонено'), backgroundColor: AppColors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  String _moderationLabel(String status) {
    switch (status) {
      case 'pending':
        return 'На модерации';
      case 'approved':
        return 'Опубликовано';
      case 'rejected':
        return 'Отклонено';
      case 'draft':
        return 'Черновик';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.name ?? 'Мастер'),
        actions: [
          IconButton(tooltip: 'Редактировать', onPressed: _detail == null ? null : _edit, icon: const Icon(Icons.edit)),
          IconButton(tooltip: 'Сброс пароля', onPressed: _detail == null ? null : _resetPassword, icon: const Icon(Icons.lock_reset)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5))))
              : _detail == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(AppLayout.screenPadding),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.inputBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Статус: ${_moderationLabel(_detail!.moderationStatus)}'
                              '${_detail!.moderationNote.isNotEmpty ? '\n${_detail!.moderationNote}' : ''}',
                              style: const TextStyle(color: AppColors.text, height: 1.35),
                            ),
                          ),
                          if (_detail!.moderationStatus == 'pending') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _approve,
                                    icon: const Icon(Icons.check),
                                    label: const Text('Одобрить'),
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _reject,
                                    icon: const Icon(Icons.close, color: Colors.redAccent),
                                    label: const Text('Отклонить', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (kMasterPointsEnabled)
                            _StatTile(label: 'Баллы', value: '${_detail!.points}'),
                          _StatTile(label: 'Долг', value: '${_detail!.debt.toStringAsFixed(0)} TJS'),
                          _StatTile(label: 'Заказов', value: '${_detail!.ordersCount}'),
                          _StatTile(label: 'Потрачено', value: '${_detail!.totalSpent.toStringAsFixed(0)} TJS'),
                          const SizedBox(height: 16),
                          if (_detail!.phone != null) _InfoRow(label: 'Телефон', value: _detail!.phone!),
                          if (_detail!.categories.isNotEmpty)
                            _InfoRow(label: 'Специализации', value: _detail!.categories.join(', ')),
                          if (_detail!.description != null && _detail!.description!.isNotEmpty)
                            _InfoRow(label: 'Описание', value: _detail!.description!),
                          if (_detail!.services.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text('Услуги', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                            for (final s in _detail!.services)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${s.name} — ${s.price.toStringAsFixed(0)} ${s.unit}',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                          ],
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            label: const Text('Удалить мастера', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.text)),
        ],
      ),
    );
  }
}
