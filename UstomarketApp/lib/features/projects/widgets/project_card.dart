import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';
import '../models/project_model.dart';

class _MediaThumb {
  const _MediaThumb({required this.path, this.isVideo = false});

  final String path;
  final bool isVideo;
}

class ProjectCard extends StatefulWidget {
  const ProjectCard({super.key, required this.project, required this.onTap});

  final ProjectModel project;
  final VoidCallback onTap;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _showBefore = true;

  ProjectModel get project => widget.project;

  List<_MediaThumb> get _beforeMedia => [
        ...project.beforeImages.map((p) => _MediaThumb(path: p)),
        if (project.beforeVideo != null)
          _MediaThumb(path: project.beforeVideo!, isVideo: true),
      ];

  List<_MediaThumb> get _afterMedia => [
        ...project.afterImages.map((p) => _MediaThumb(path: p)),
        if (project.afterVideo != null)
          _MediaThumb(path: project.afterVideo!, isVideo: true),
      ];

  List<_MediaThumb> get _activeMedia => _showBefore ? _beforeMedia : _afterMedia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final settings = Provider.of<SettingsProvider>(context);
    final activeMedia = _activeMedia;
    final heroPath = activeMedia.isNotEmpty && !activeMedia.first.isVideo
        ? activeMedia.first.path
        : (project.beforeImages.isNotEmpty
            ? project.beforeImages.first
            : (project.afterImages.isNotEmpty
                ? project.afterImages.first
                : null));

    final statusColor =
        project.hasDebt ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final statusLabel = project.hasDebt
        ? '${settings.t('project_debt_left')}: ${_formatMoney(project.debtAmount)}'
        : settings.t('project_paid');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
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
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: heroPath != null && heroPath.isNotEmpty
                      ? Image.file(
                          File(heroPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(isDark),
                        )
                      : _placeholder(isDark),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            project.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'd.MM.y',
                            settings.intlLocaleCode,
                          ).format(project.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: onSurface.withValues(alpha: 0.54),
                          ),
                        ),
                      ],
                    ),
                    if (project.client.trim().isNotEmpty ||
                        project.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _clientLine(settings),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildMediaTabs(settings, onSurface),
                    const SizedBox(height: 10),
                    _buildMediaStrip(isDark, activeMedia),
                    const SizedBox(height: 16),
                    _buildFinanceRow(settings, onSurface),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _clientLine(SettingsProvider settings) {
    final parts = <String>[];
    if (project.client.trim().isNotEmpty) {
      parts.add('${settings.t('project_client')}: ${project.client.trim()}');
    }
    if (project.phone.trim().isNotEmpty) {
      parts.add('${settings.t('phone')}: ${project.phone.trim()}');
    }
    return parts.join(', ');
  }

  Widget _buildMediaTabs(SettingsProvider settings, Color onSurface) {
    return Row(
      children: [
        _MediaTab(
          label: settings.t('project_tab_before'),
          selected: _showBefore,
          onTap: () => setState(() => _showBefore = true),
        ),
        const SizedBox(width: 8),
        _MediaTab(
          label: settings.t('project_tab_after'),
          selected: !_showBefore,
          onTap: () => setState(() => _showBefore = false),
        ),
      ],
    );
  }

  Widget _buildMediaStrip(bool isDark, List<_MediaThumb> media) {
    if (media.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.centerLeft,
        child: Text(
          '—',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: 13,
          ),
        ),
      );
    }

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = media[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.isVideo)
                    Container(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFE5E7EB),
                      child: const Icon(
                        Icons.videocam_outlined,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                    )
                  else
                    Image.file(
                      File(item.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE5E7EB),
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  if (item.isVideo)
                    Container(
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinanceRow(SettingsProvider settings, Color onSurface) {
    return Row(
      children: [
        Expanded(
          child: _FinanceColumn(
            label: settings.t('project_income'),
            value: _formatMoney(project.income),
            onSurface: onSurface,
          ),
        ),
        Expanded(
          child: _FinanceColumn(
            label: settings.t('project_received_short'),
            value: _formatMoney(project.receivedAmount),
            onSurface: onSurface,
          ),
        ),
        Expanded(
          child: _FinanceColumn(
            label: settings.t('project_debt_label'),
            value: _formatMoney(project.debtAmount),
            onSurface: onSurface,
            valueColor: project.hasDebt
                ? const Color(0xFFEA580C)
                : AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 46,
        color: AppColors.textSecondary,
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
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderIdle =
        isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12);
    final labelIdle = isDark ? Colors.white54 : Colors.black54;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : borderIdle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.accent : labelIdle,
            ),
          ),
        ),
      ),
    );
  }
}

class _FinanceColumn extends StatelessWidget {
  const _FinanceColumn({
    required this.label,
    required this.value,
    required this.onSurface,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color onSurface;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: onSurface.withValues(alpha: 0.54),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor ?? onSurface,
          ),
        ),
      ],
    );
  }
}
