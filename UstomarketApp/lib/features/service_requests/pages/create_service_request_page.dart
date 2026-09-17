import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/client_auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../models/service_order.dart';
import '../services/service_catalog_api.dart';
import 'map_location_picker_page.dart';

/// Клиент: категория → услуга → место → заказ.
class CreateServiceRequestPage extends StatefulWidget {
  const CreateServiceRequestPage({super.key});

  @override
  State<CreateServiceRequestPage> createState() =>
      _CreateServiceRequestPageState();
}

class _CreateServiceRequestPageState extends State<CreateServiceRequestPage> {
  List<ServiceCategory> _categories = [];
  List<CatalogService> _services = [];
  ServiceCategory? _category;
  CatalogService? _service;
  final _addressCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  double? _latitude;
  double? _longitude;
  bool _loading = true;
  bool _submitting = false;

  String get _dateLabel {
    final d = _scheduledDate;
    if (d == null) return 'Выберите дату';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  String get _dateApi {
    final d = _scheduledDate!;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String get _timeLabel {
    final t = _scheduledTime;
    if (t == null) return 'Выберите время';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => _scheduledTime = picked);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<MapPickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  String get _mapStatusLabel {
    if (_latitude == null || _longitude == null) {
      return 'Точка на карте не выбрана';
    }
    return 'Точка: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}';
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String? _loadError;

  Future<void> _loadCategories() async {
    try {
      final cats = await ServiceCatalogApi.instance.categories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _category = cats.isNotEmpty ? cats.first : null;
        _loading = false;
        _loadError = cats.isEmpty ? 'Каталог услуг пуст' : null;
      });
      if (_category != null) await _loadServices();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Не удалось загрузить каталог: $e';
        });
      }
    }
  }

  Future<void> _loadServices() async {
    final cat = _category;
    if (cat == null) return;
    setState(() {
      _services = [];
      _service = null;
    });
    try {
      final list = await ServiceCatalogApi.instance.services(categoryId: cat.id);
      if (!mounted) return;
      setState(() {
        _services = list;
        _service = list.isNotEmpty ? list.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки услуг: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final settings = context.read<SettingsProvider>();
    final client = context.read<ClientAuthProvider>();
    final token = client.accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('sr_login_in_profile'))),
      );
      return;
    }
    final service = _service;
    if (service == null) return;
    final address = _addressCtrl.text.trim();
    if (address.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите текстовый ориентир (район / ориентир)'),
        ),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите место на карте')),
      );
      return;
    }
    if (_scheduledDate == null || _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите дату и время')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ServiceCatalogApi.instance.createOrder(
        clientToken: token,
        serviceId: service.id,
        address: address,
        comment: _commentCtrl.text.trim(),
        scheduledDate: _dateApi,
        scheduledTime: _timeLabel,
        latitude: _latitude!,
        longitude: _longitude!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заказ опубликован в ленте'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('sr_create_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _loadError = null;
                            });
                            _loadCategories();
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Категория', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _category?.id,
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (id) async {
                    if (id == null) return;
                    final c = _categories.firstWhere((e) => e.id == id);
                    setState(() => _category = c);
                    await _loadServices();
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text('Услуга', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_services.isEmpty)
                  const Text('Нет активных услуг в категории')
                else
                  ..._services.map((s) {
                    final selected = _service?.id == s.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : null,
                      child: ListTile(
                        title: Text(
                          s.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${s.priceClient.toStringAsFixed(0)} сомони',
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: AppColors.accent)
                            : null,
                        onTap: () => setState(() => _service = s),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                Text('Местоположение', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Текстовый ориентир',
                    hintText: 'например, микрорайон Гулистан, возле чайханы',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickOnMap,
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Указать на карте'),
                ),
                const SizedBox(height: 6),
                Text(
                  _mapStatusLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: _latitude == null
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Дата и время', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_dateLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.access_time),
                        label: Text(_timeLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ||
                            _service == null ||
                            _scheduledDate == null ||
                            _scheduledTime == null ||
                            _latitude == null ||
                            _longitude == null
                        ? null
                        : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentContrastText,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Подтвердить заказ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
