import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/admin_masters_api.dart';
import '../constants.dart';

class MasterEditScreen extends StatefulWidget {
  const MasterEditScreen({super.key, this.masterId});

  /// null = создать нового мастера
  final int? masterId;

  @override
  State<MasterEditScreen> createState() => _MasterEditScreenState();
}

class _MasterEditScreenState extends State<MasterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _experienceController = TextEditingController(text: '0');
  final _newCategoryController = TextEditingController();

  List<String> _allCategories = [];
  final Set<String> _selectedCategories = {};
  final List<_ServiceRow> _services = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cats = await AdminMastersCrudApi.fetchCategories();
      if (widget.masterId != null) {
        final detail = await AdminMastersCrudApi.fetchDetail(widget.masterId!);
        _nameController.text = detail.name ?? '';
        _phoneController.text = detail.phone ?? '';
        _descriptionController.text = detail.description ?? '';
        _experienceController.text = '${detail.experience}';
        _selectedCategories.addAll(detail.categories);
        for (final s in detail.services) {
          final row = _ServiceRow();
          row.name.text = s.name;
          row.price.text = s.price.toStringAsFixed(0);
          row.unit.text = s.unit;
          _services.add(row);
        }
      }
      if (mounted) {
        setState(() {
          _allCategories = cats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _experienceController.dispose();
    _newCategoryController.dispose();
    for (final s in _services) {
      s.name.dispose();
      s.price.dispose();
      s.unit.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = MasterDraft(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      description: _descriptionController.text.trim(),
      experience: int.tryParse(_experienceController.text.trim()) ?? 0,
      categories: _selectedCategories.toList(),
      newCategory: _newCategoryController.text.trim().isEmpty ? null : _newCategoryController.text.trim(),
      services: _services
          .where((r) => r.name.text.trim().isNotEmpty)
          .map(
            (r) => MasterServiceDraft(
              name: r.name.text.trim(),
              price: double.tryParse(r.price.text.replaceAll(',', '.')) ?? 0,
              unit: r.unit.text.trim(),
            ),
          )
          .toList(),
    );

    setState(() => _saving = true);
    try {
      if (widget.masterId == null) {
        await AdminMastersCrudApi.create(draft);
      } else {
        await AdminMastersCrudApi.update(widget.masterId!, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.masterId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Редактировать мастера' : 'Новый мастер')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Имя'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Телефон'),
                      validator: (v) => (v == null || v.trim().length < 9) ? 'Минимум 9 цифр' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Описание'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Опыт (лет)'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Специализации', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _allCategories)
                          FilterChip(
                            label: Text(c),
                            selected: _selectedCategories.contains(c),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _selectedCategories.add(c);
                                } else {
                                  _selectedCategories.remove(c);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'Новая специализация',
                        hintText: 'Добавить свою',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Услуги', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 8),
                    for (final row in _services)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.name,
                                decoration: const InputDecoration(hintText: 'Услуга'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: row.price,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'Цена'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 56,
                              child: TextField(
                                controller: row.unit,
                                decoration: const InputDecoration(hintText: 'ед.'),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _services.remove(row)),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _services.add(_ServiceRow())),
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить услугу'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isEdit ? 'Сохранить' : 'Создать мастера'),
          ),
        ),
      ),
    );
  }
}

class _ServiceRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController unit = TextEditingController(text: 'шт');
}
