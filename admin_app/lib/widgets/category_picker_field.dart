import 'package:flutter/material.dart';

import '../constants.dart';

/// Выбор категории/подкатегории из списка или создание новой.
class CategoryPickerField extends StatefulWidget {
  const CategoryPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.allowCreate = true,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool allowCreate;

  static const createNewValue = '__NEW__';

  @override
  State<CategoryPickerField> createState() => _CategoryPickerFieldState();
}

class _CategoryPickerFieldState extends State<CategoryPickerField> {
  final _newController = TextEditingController();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _syncCreateMode();
  }

  @override
  void didUpdateWidget(covariant CategoryPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _syncCreateMode();
    }
  }

  void _syncCreateMode() {
    final sel = widget.selected;
    if (sel == null || sel.isEmpty) {
      _creating = false;
      return;
    }
    _creating = !widget.options.contains(sel);
    if (_creating) _newController.text = sel;
  }

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  List<String> get _dropdownItems {
    final items = [...widget.options];
    if (widget.allowCreate) items.add(CategoryPickerField.createNewValue);
    return items;
  }

  String? get _dropdownValue {
    final sel = widget.selected;
    if (sel == null || sel.isEmpty) return null;
    if (widget.options.contains(sel)) return sel;
    if (widget.allowCreate) return CategoryPickerField.createNewValue;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decoration = InputDecoration(
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _dropdownValue,
          decoration: decoration.copyWith(labelText: widget.label),
          hint: Text('Выберите ${widget.label.toLowerCase()}'),
          items: [
            for (final o in _dropdownItems)
              DropdownMenuItem(
                value: o,
                child: Text(
                  o == CategoryPickerField.createNewValue ? '+ Создать новую' : o,
                ),
              ),
          ],
          onChanged: (v) {
            if (v == null) {
              setState(() {
                _creating = false;
                _newController.clear();
              });
              widget.onChanged(null);
              return;
            }
            if (v == CategoryPickerField.createNewValue) {
              setState(() => _creating = true);
              widget.onChanged(_newController.text.trim().isEmpty ? '' : _newController.text.trim());
              return;
            }
            setState(() {
              _creating = false;
              _newController.clear();
            });
            widget.onChanged(v);
          },
        ),
        if (_creating) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _newController,
            decoration: decoration.copyWith(
              labelText: 'Новая ${widget.label.toLowerCase()}',
              hintText: 'Введите название',
            ),
            onChanged: (v) => widget.onChanged(v.trim()),
          ),
        ],
      ],
    );
  }
}

/// Компактный чип фильтра категорий.
class CategoryFilterChips extends StatelessWidget {
  const CategoryFilterChips({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (ctx, i) {
          final selected = i == selectedIndex;
          return ChoiceChip(
            label: Text(categories[i]),
            selected: selected,
            onSelected: (_) => onSelected(i),
            selectedColor: AppColors.accent.withValues(alpha: 0.25),
            backgroundColor: AppColors.cardElevated,
            labelStyle: TextStyle(
              color: selected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }
}
