import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants.dart';
import '../models/product.dart';
import '../api/admin_products_api.dart';
import '../widgets/category_picker_field.dart';

class ProductEditScreen extends StatefulWidget {
  final AdminProduct? product;

  const ProductEditScreen({super.key, this.product});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _brandController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;

  String? _category;
  String? _subcategory;
  List<String> _categories = [];
  List<String> _subcategories = [];
  bool _loadingMeta = true;
  bool _saving = false;
  final List<_SizeRow> _sizes = [];
  final List<_ColorRow> _colors = [];
  final List<XFile> _images = [];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name);
    _skuController = TextEditingController(text: p?.articul);
    _brandController = TextEditingController(text: p?.brand);
    _unitController = TextEditingController(text: p?.unit ?? 'шт');
    _priceController = TextEditingController(text: p?.price.toStringAsFixed(0));
    _descriptionController = TextEditingController(text: p?.description);
    _category = p?.category;
    _subcategory = p?.subcategory;
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    try {
      final meta = await AdminProductsApi.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = meta.categories;
        _subcategories = meta.subcategories;
        _loadingMeta = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _brandController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    for (final s in _sizes) {
      s.name.dispose();
      s.price.dispose();
    }
    for (final c in _colors) {
      c.name.dispose();
      c.value.dispose();
    }
    super.dispose();
  }

  String? _resolveCategoryForDraft() {
    final cat = (_category ?? '').trim();
    if (cat.isEmpty) return null;
    if (_categories.contains(cat)) return cat;
    return null;
  }

  String? _resolveNewCategoryForDraft() {
    final cat = (_category ?? '').trim();
    if (cat.isEmpty) return null;
    if (_categories.contains(cat)) return null;
    return cat;
  }

  String? _resolveSubcategoryForDraft() {
    final sub = (_subcategory ?? '').trim();
    if (sub.isEmpty) return null;
    if (_subcategories.contains(sub)) return sub;
    return null;
  }

  String? _resolveNewSubcategoryForDraft() {
    final sub = (_subcategory ?? '').trim();
    if (sub.isEmpty) return null;
    if (_subcategories.contains(sub)) return null;
    return sub;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_category ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите или создайте категорию')),
      );
      return;
    }

    final draft = AdminProductDraft(
      name: _nameController.text.trim(),
      price: double.parse(_priceController.text.replaceAll(',', '.')),
      brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
      category: _resolveCategoryForDraft(),
      newCategory: _resolveNewCategoryForDraft(),
      subcategory: _resolveSubcategoryForDraft(),
      newSubcategory: _resolveNewSubcategoryForDraft(),
      articul: _skuController.text.trim(),
      description: _descriptionController.text.trim(),
      unit: _unitController.text.trim().isEmpty ? 'шт' : _unitController.text.trim(),
      sizesNames: _sizes.map((e) => e.name.text.trim()).where((t) => t.isNotEmpty).toList(),
      sizesPrices: _sizes
          .map((e) => double.tryParse(e.price.text.replaceAll(',', '.')) ?? 0)
          .toList(),
      colorsNames: _colors.map((e) => e.name.text.trim()).where((t) => t.isNotEmpty).toList(),
      colorsValues: _colors.map((e) => e.value.text.trim()).where((t) => t.isNotEmpty).toList(),
    );

    setState(() => _saving = true);
    try {
      final files = <http.MultipartFile>[];
      for (final img in _images) {
        files.add(await http.MultipartFile.fromPath('files', img.path));
      }

      if (widget.product == null) {
        await AdminProductsApi.createProduct(draft, files: files);
      } else {
        await AdminProductsApi.updateProduct(
          widget.product!.id,
          draft,
          existingPhotos: widget.product!.photos,
          newFiles: files,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.product != null;

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Редактировать товар' : 'Новый товар'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: inputDecoration.copyWith(labelText: 'Название'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skuController,
                      decoration: inputDecoration.copyWith(labelText: 'Код / штрихкод'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите код' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _brandController,
                      decoration: inputDecoration.copyWith(labelText: 'Бренд'),
                    ),
                    const SizedBox(height: 12),
                    CategoryPickerField(
                      label: 'Категория',
                      options: _categories,
                      selected: _category,
                      onChanged: (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 12),
                    CategoryPickerField(
                      label: 'Подкатегория',
                      options: _subcategories,
                      selected: _subcategory,
                      onChanged: (v) => setState(() => _subcategory = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unitController,
                      decoration: inputDecoration.copyWith(labelText: 'Ед. измерения'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: inputDecoration.copyWith(labelText: 'Цена продажи (TJS)'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите цену' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: inputDecoration.copyWith(labelText: 'Описание'),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Размеры (имя + цена)', style: TextStyle(color: theme.colorScheme.onSurface)),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        for (final row in _sizes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: row.name,
                                    decoration: inputDecoration.copyWith(hintText: 'Размер (например, 25 кг)'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: row.price,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: inputDecoration.copyWith(hintText: 'Цена'),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _sizes.remove(row)),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() => _sizes.add(_SizeRow())),
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить размер'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Цвета', style: TextStyle(color: theme.colorScheme.onSurface)),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        for (final row in _colors)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: row.name,
                                    decoration: inputDecoration.copyWith(hintText: 'Название цвета'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: row.value,
                                    decoration: inputDecoration.copyWith(hintText: '#RRGGBB'),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _colors.remove(row)),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() => _colors.add(_ColorRow())),
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить цвет'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Фото товара', style: TextStyle(color: theme.colorScheme.onSurface)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.product?.image != null && widget.product!.image!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              buildImageUrl(widget.product!.image),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        for (final img in _images)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(img.path),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.remove(img)),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery);
                            if (picked != null) setState(() => _images.add(picked));
                          },
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: theme.colorScheme.surface,
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
}

class _ColorRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController value = TextEditingController();
}
