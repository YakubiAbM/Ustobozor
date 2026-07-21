import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';

class IncomeStats extends StatelessWidget {
  const IncomeStats({
    super.key,
    required this.monthIncome,
    required this.projectCount,
  });

  final double monthIncome;
  final int projectCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final settings = Provider.of<SettingsProvider>(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.t('projects_month_income'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${_formatMoney(monthIncome)} ${settings.t('currency_somoni')}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$projectCount ${_projectsWord(settings, projectCount)}',
            style: TextStyle(
              fontSize: 15,
              color: onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMoney(double value) {
    final number = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < number.length; i++) {
      final reversedIndex = number.length - i;
      buffer.write(number[i]);
      if (reversedIndex > 1 && reversedIndex % 3 == 1) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  static String _projectsWord(SettingsProvider settings, int count) {
    if (count == 1) return settings.t('project_count_one');
    if (count >= 2 && count <= 4) return settings.t('project_count_few');
    return settings.t('project_count_many');
  }
}
