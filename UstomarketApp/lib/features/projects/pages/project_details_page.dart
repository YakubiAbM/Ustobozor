import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';
import '../../../screens/full_screen_gallery_screen.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';
import '../widgets/project_video_player.dart';
import 'add_project_page.dart';

class ProjectDetailsPage extends StatefulWidget {
  const ProjectDetailsPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  ProjectModel? _project;
  bool _loading = true;
  int _currentBeforeImageIndex = 0;
  int _currentAfterImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    final project = await ProjectStorageService.instance.getProjectById(
      widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _project = project;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final settings = Provider.of<SettingsProvider>(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_project == null) {
      return Scaffold(
        appBar: AppBar(title: Text(settings.t('my_projects'))),
        body: Center(
          child: Text(
            settings.t('project_not_found'),
            style: TextStyle(color: onSurface.withValues(alpha: 0.8)),
          ),
        ),
      );
    }

    final project = _project!;
    final statusColor =
        project.hasDebt ? const Color(0xFFEA580C) : AppColors.accent;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('project_details')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (project.beforeImages.isNotEmpty) ...[
            Text(
              settings.t('project_before_photos'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildImageGallerySection(
              context,
              images: project.beforeImages,
              currentIndex: _currentBeforeImageIndex,
              onPageChanged: (index) {
                setState(() => _currentBeforeImageIndex = index);
              },
            ),
            const SizedBox(height: 20),
          ],
          if (project.afterImages.isNotEmpty) ...[
            Text(
              settings.t('project_after_photos'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildImageGallerySection(
              context,
              images: project.afterImages,
              currentIndex: _currentAfterImageIndex,
              onPageChanged: (index) {
                setState(() => _currentAfterImageIndex = index);
              },
            ),
            const SizedBox(height: 20),
          ],
          if (project.beforeVideo != null) ...[
            Text(
              settings.t('project_before_video'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ProjectVideoPlayer(videoPath: project.beforeVideo!),
            const SizedBox(height: 20),
          ],
          if (project.afterVideo != null) ...[
            Text(
              settings.t('project_after_video'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ProjectVideoPlayer(videoPath: project.afterVideo!),
            const SizedBox(height: 20),
          ],
          if (project.beforeImages.isEmpty && project.afterImages.isEmpty) ...[
            SizedBox(
              height: 220,
              child: _placeholder(theme.brightness == Brightness.dark),
            ),
            const SizedBox(height: 20),
          ],
          _sectionCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow(
                  settings.t('project_client'),
                  project.client.isEmpty
                      ? settings.t('project_not_specified')
                      : project.client,
                ),
                _detailRow(
                  settings.t('project_phone_label'),
                  project.phone.isEmpty
                      ? settings.t('project_not_specified')
                      : project.phone,
                ),
                _detailRow(
                  settings.t('project_date'),
                  DateFormat(
                    'd MMMM y',
                    settings.intlLocaleCode,
                  ).format(project.date),
                ),
                _detailRow(
                  settings.t('project_income'),
                  '${_formatMoney(project.income)} ${settings.t('currency_somoni')}',
                ),
                _detailRow(
                  settings.t('project_received_label'),
                  '${_formatMoney(project.receivedAmount)} ${settings.t('currency_somoni')}',
                ),
                if (project.hasDebt)
                  _detailRow(
                    settings.t('project_debt_label'),
                    '${_formatMoney(project.debtAmount)} ${settings.t('currency_somoni')}',
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.t('project_payment_status_label'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          settings.t(
                            project.hasDebt
                                ? 'project_has_debt'
                                : 'project_paid',
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _detailRow(
                  settings.t('project_note'),
                  project.note.isEmpty
                      ? settings.t('project_no_note')
                      : project.note,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editProject,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(settings.t('projects_edit')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _deleteProject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD74C4C),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(settings.t('project_delete')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallerySection(
    BuildContext context, {
    required List<String> images,
    required int currentIndex,
    required ValueChanged<int> onPageChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final imagePath = images[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenGalleryScreen(
                        imageUrls: images,
                        initialIndex: index,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 220,
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _placeholder(isDark, height: 220),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              right: 16,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${currentIndex + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: child,
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, height: 1.35)),
        ],
      ),
    );
  }

  Widget _placeholder(bool isDark, {double height = 220}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 46,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Future<void> _editProject() async {
    final project = _project;
    if (project == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProjectPage(initialProject: project),
      ),
    );

    if (updated == true) {
      await _loadProject();
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _deleteProject() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('project_delete_confirm_title')),
        content: Text(settings.t('project_delete_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(settings.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(settings.t('project_delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ProjectStorageService.instance.deleteProject(widget.projectId);
    if (!mounted) return;
    Navigator.pop(context, true);
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
