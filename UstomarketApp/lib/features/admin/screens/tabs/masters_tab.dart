import 'dart:async';
import 'package:flutter/material.dart';

import '../../api/admin_dashboard_api.dart';
import '../../constants.dart';
import '../../models/admin_master.dart';
import '../../widgets/admin_section_header.dart';
import '../master_detail_screen.dart';
import '../master_edit_screen.dart';

class MastersTab extends StatefulWidget {
  const MastersTab({super.key});

  @override
  State<MastersTab> createState() => _MastersTabState();
}

class _MastersTabState extends State<MastersTab> {
  final _searchController = TextEditingController();
  List<AdminMaster> _masters = [];
  bool _loading = true;
  String? _error;
  Timer? _searchDebounce;
  /// null = все, pending = на модерации
  String? _moderationFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await AdminMastersApi.fetch(
        search: _searchController.text,
        moderationStatus: _moderationFilter,
      );
      if (!mounted) return;
      setState(() {
        _masters = items;
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

  Future<void> _resetPassword(AdminMaster master) async {
    final name = master.name ?? 'мастера';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Сброс пароля', style: TextStyle(color: AppColors.text)),
        content: Text(
          'Сбросить пароль для «$name»?\n\n'
          'Мастер сможет задать новый пароль при следующем входе в приложение или на сайте.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
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
      final message = await AdminMastersApi.resetPassword(master.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.accent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _openCreate() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MasterEditScreen()),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdminSectionHeader(title: 'Мастера'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Все'),
                    selected: _moderationFilter == null,
                    onSelected: (_) {
                      setState(() => _moderationFilter = null);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('На модерации'),
                    selected: _moderationFilter == 'pending',
                    onSelected: (_) {
                      setState(() => _moderationFilter = 'pending');
                      _load();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Поиск по имени или телефону',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                  ),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _load(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5))),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _masters.isEmpty
                      ? const Center(
                          child: Text(
                            'Мастеров не найдено',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.accent,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _masters.length,
                            itemBuilder: (ctx, i) => _MasterCard(
                              master: _masters[i],
                              onTap: () async {
                                final deleted = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MasterDetailScreen(masterId: _masters[i].id),
                                  ),
                                );
                                if (deleted == true) _load();
                              },
                              onResetPassword: () => _resetPassword(_masters[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add),
        label: const Text('Мастер'),
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({
    required this.master,
    required this.onTap,
    required this.onResetPassword,
  });

  final AdminMaster master;
  final VoidCallback onTap;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    final cats = master.categories.isEmpty ? '—' : master.categories.take(2).join(', ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppLayout.radiusLg),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppLayout.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.inputBg,
            child: Text(
              (master.name ?? '?').substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  master.name ?? 'Без имени',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  master.phone ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  cats,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                if (master.moderationStatus == 'pending' ||
                    master.moderationStatus == 'rejected' ||
                    master.moderationStatus == 'draft')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      master.moderationStatus == 'pending'
                          ? 'На модерации'
                          : master.moderationStatus == 'rejected'
                              ? 'Отклонено'
                              : 'Черновик',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: master.moderationStatus == 'pending'
                            ? AppColors.orange
                            : Colors.redAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (kMasterPointsEnabled)
                Text(
                  '${master.points} б.',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (master.debt > 0)
                Text(
                  'долг ${master.debt.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.orange),
                ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onResetPassword,
                icon: const Icon(Icons.lock_reset, size: 16),
                label: const Text('Сброс пароля'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}
