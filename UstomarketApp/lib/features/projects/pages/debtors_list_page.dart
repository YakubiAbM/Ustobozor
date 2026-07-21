import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';
import '../models/project_model.dart';
import 'debt_repayment_page.dart';

/// Список должников: проекты, где доход > получено (есть долг).
class DebtorsListPage extends StatelessWidget {
  const DebtorsListPage({
    super.key,
    required this.debtProjects,
  });

  final List<ProjectModel> debtProjects;

  static double _debtAmount(ProjectModel p) => p.debtAmount;

  static String _formatMoney(double value) {
    final s = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buffer.write(s[i]);
      final fromEnd = s.length - i - 1;
      if (fromEnd > 0 && fromEnd % 3 == 0) buffer.write(' ');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surfaceColor = theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('debts_list_title')),
        centerTitle: true,
      ),
      body: debtProjects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settings.t('debts_empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: debtProjects.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final project = debtProjects[index];
                final debt = _debtAmount(project);
                final name = project.client.trim().isEmpty
                    ? project.title
                    : project.client;
                final phone = project.phone.trim().isEmpty
                    ? settings.t('project_not_specified')
                    : project.phone;

                return Material(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DebtRepaymentPage(projectId: project.id),
                        ),
                      );
                      if (updated == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: AppColors.accent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phone,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: onSurface.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${_formatMoney(debt)} ${settings.t('currency_somoni')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
