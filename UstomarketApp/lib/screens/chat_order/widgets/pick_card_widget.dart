import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../widgets/app_cached_image.dart';
import '../models/pick_models.dart';

class PickCardWidget extends StatelessWidget {
  final PickPayload pick;
  final void Function(int productId) onOptionSelected;

  /// Текст сверху, если сервер не прислал prompt (например: «Выберите вариант (размер или цвет)»).
  final String? defaultPrompt;

  const PickCardWidget({
    super.key,
    required this.pick,
    required this.onOptionSelected,
    this.defaultPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final promptText = pick.prompt.isNotEmpty
        ? pick.prompt
        : (defaultPrompt ?? 'Выберите вариант:');
    return Container(
      margin: const EdgeInsets.only(right: 24, left: 8, top: 6, bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              promptText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.95),
              ),
            ),
          ),
          ...pick.options.map(
            (opt) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PickOptionCard(
                option: opt,
                isDark: isDark,
                theme: theme,
                onTap: () => onOptionSelected(opt.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickOptionCard extends StatelessWidget {
  final PickOption option;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _PickOptionCard({
    required this.option,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                child: option.image.isEmpty
                    ? const Icon(Icons.image_outlined, color: Colors.grey)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AppCachedImage(
                          imagePath: option.image,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(10),
                          fallbackIcon: Icons.image_not_supported,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${option.price.toInt()} ${option.unit}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.check_circle_outline,
                color: AppColors.accent,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
