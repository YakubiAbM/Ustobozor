import 'package:flutter/material.dart';

import '../../../constants.dart';
import '../models/chat_response_models.dart';

/// Горизонтальный выбор варианта (TZ §4.1): фиксированная высота 120 px.
class HorizontalOptionsSelector extends StatelessWidget {
  static const double panelHeight = 120;

  final PendingItem pendingItem;
  final bool isLoading;
  final ValueChanged<int> onOptionSelected;
  final String? defaultPrompt;

  const HorizontalOptionsSelector({
    super.key,
    required this.pendingItem,
    required this.isLoading,
    required this.onOptionSelected,
    this.defaultPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prompt = pendingItem.userQuery.isNotEmpty
        ? pendingItem.userQuery
        : (defaultPrompt ?? 'Выберите вариант:');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: panelHeight,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : AppColors.cardBgLight,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              prompt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.9),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: pendingItem.options.length,
              itemBuilder: (context, index) {
                final opt = pendingItem.options[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: _OptionChip(
                    label: opt.label.isNotEmpty
                        ? opt.label
                        : '${opt.name} — ${opt.price.toInt()} ${opt.unit}',
                    enabled: !isLoading,
                    onPressed: isLoading
                        ? null
                        : () => onOptionSelected(opt.productId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  const _OptionChip({
    required this.label,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: enabled
          ? theme.colorScheme.surface
          : theme.colorScheme.surface.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? AppColors.accent.withOpacity(0.5) : Colors.grey,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}
