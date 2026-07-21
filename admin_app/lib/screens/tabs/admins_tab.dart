import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/admin_admins_api.dart';
import '../../constants.dart';
import '../../widgets/admin_section_header.dart';

class AdminsTab extends StatefulWidget {
  const AdminsTab({super.key});

  @override
  State<AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<AdminsTab> {
  List<AdminStaffUser> _admins = [];
  AdminScopeInfo? _scopes;
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
      final results = await Future.wait([
        AdminStaffApi.fetchAll(),
        AdminStaffApi.fetchScopes(),
      ]);
      if (!mounted) return;
      setState(() {
        _admins = results[0] as List<AdminStaffUser>;
        _scopes = results[1] as AdminScopeInfo;
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

  Future<void> _openEditor([AdminStaffUser? admin]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AdminEditorSheet(admin: admin, scopes: _scopes),
    );
    if (changed == true) _load();
  }

  Future<void> _remove(AdminStaffUser admin) async {
    if (admin.isSuperadmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Удалить админа?', style: TextStyle(color: AppColors.text)),
        content: Text('«${admin.name}» (${admin.phone})', style: const TextStyle(color: AppColors.textSecondary)),
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
    if (ok != true) return;
    try {
      await AdminStaffApi.remove(admin.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdminSectionHeader(title: 'Админы'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: _admins.length,
                        itemBuilder: (ctx, i) {
                          final a = _admins[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: AppColors.cardElevated,
                            child: ListTile(
                              title: Text(a.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    a.isSuperadmin
                                        ? 'Супер-админ (все разделы)'
                                        : a.permissions.map((p) => _scopes?.labels[p] ?? p).join(', '),
                                    style: const TextStyle(fontSize: 11, color: AppColors.accent),
                                  ),
                                ],
                              ),
                              trailing: a.isSuperadmin
                                  ? null
                                  : PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') _openEditor(a);
                                        if (v == 'delete') _remove(a);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                                        PopupMenuItem(value: 'delete', child: Text('Удалить')),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Новый админ'),
      ),
    );
  }
}

class _AdminEditorSheet extends StatefulWidget {
  const _AdminEditorSheet({this.admin, this.scopes});

  final AdminStaffUser? admin;
  final AdminScopeInfo? scopes;

  @override
  State<_AdminEditorSheet> createState() => _AdminEditorSheetState();
}

class _AdminEditorSheetState extends State<_AdminEditorSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final Set<String> _permissions = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.admin;
    if (a != null) {
      _nameController.text = a.name;
      _phoneController.text = a.phone;
      _permissions.addAll(a.permissions);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите телефон'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final pin = _pinController.text.trim();
    if (widget.admin == null && pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN — 4 цифры'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_permissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один раздел'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final draft = AdminStaffDraft(
      name: _nameController.text.trim(),
      phone: phone,
      pin: pin,
      permissions: _permissions.toList(),
    );

    setState(() => _saving = true);
    try {
      if (widget.admin == null) {
        await AdminStaffApi.create(draft);
      } else {
        await AdminStaffApi.update(widget.admin!.id, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scopes = widget.scopes?.scopes ?? [];
    final labels = widget.scopes?.labels ?? {};
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.admin == null ? 'Новый админ' : 'Редактировать админа',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Телефон'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: widget.admin == null ? 'PIN (4 цифры)' : 'Новый PIN (оставьте пустым)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Доступ к разделам', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in scopes)
                  FilterChip(
                    label: Text(labels[s] ?? s),
                    selected: _permissions.contains(s),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _permissions.add(s);
                        } else {
                          _permissions.remove(s);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
