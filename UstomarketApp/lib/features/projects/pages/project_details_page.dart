import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';
import '../../../screens/full_screen_gallery_screen.dart';
import '../../../utils/phone_launcher.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';
import '../widgets/project_video_player.dart';
import 'add_project_page.dart';
import 'sketch_board_page.dart';

class ProjectDetailsPage extends StatefulWidget {
  const ProjectDetailsPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage>
    with SingleTickerProviderStateMixin {
  ProjectModel? _project;
  bool _loading = true;
  late TabController _tabs;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadProject();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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

  Future<void> _persist(ProjectModel project) async {
    final saved = await ProjectStorageService.instance.updateProject(project);
    if (!mounted) return;
    setState(() => _project = saved);
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
        project.hasDebt ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editProject,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          labelColor: AppColors.accent,
          unselectedLabelColor: onSurface.withValues(alpha: 0.55),
          indicatorColor: AppColors.accent,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          tabs: [
            Tab(
              icon: const Icon(Icons.payments_outlined, size: 20),
              text: settings.t('project_tab_finance'),
            ),
            Tab(
              icon: const Icon(Icons.checklist_outlined, size: 20),
              text: settings.t('project_tab_notes'),
            ),
            Tab(
              icon: const Icon(Icons.brush_outlined, size: 20),
              text: settings.t('project_tab_sketch'),
            ),
            Tab(
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              text: settings.t('project_tab_gallery'),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  project.hasDebt
                      ? '${settings.t('project_debt_left')}: ${_formatMoney(project.debtAmount)} ${settings.t('currency_somoni')}'
                      : settings.t('project_paid'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _FinanceTab(
                  project: project,
                  onChanged: _persist,
                  onToggleCompleted: () => _persist(
                    project.copyWith(isCompleted: !project.isCompleted),
                  ),
                  onDelete: _deleteProject,
                ),
                _NotesTab(project: project, onChanged: _persist),
                _SketchTab(project: project, onChanged: _persist),
                _GalleryTab(
                  project: project,
                  onChanged: _persist,
                  picker: _picker,
                ),
              ],
            ),
          ),
        ],
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
    if (updated == true) await _loadProject();
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
      if (reversedIndex > 1 && reversedIndex % 3 == 1) buffer.write(' ');
    }
    return buffer.toString();
  }
}

class _FinanceTab extends StatelessWidget {
  const _FinanceTab({
    required this.project,
    required this.onChanged,
    required this.onToggleCompleted,
    required this.onDelete,
  });

  final ProjectModel project;
  final ValueChanged<ProjectModel> onChanged;
  final VoidCallback onToggleCompleted;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.t('project_tab_finance'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                project.client.isEmpty
                    ? settings.t('project_not_specified')
                    : project.client,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              if (project.address.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: onSurface.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        project.address,
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (project.phone.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  formatTjPhoneDisplay(project.phone),
                  style: TextStyle(color: onSurface.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            launchPhoneCall(context, project.phone),
                        icon: const Icon(Icons.phone),
                        label: Text(settings.t('call')),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.accentContrastText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            launchWhatsApp(context, project.phone),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(settings.t('project_write_whatsapp')),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          isDark,
          child: Column(
            children: [
              _moneyRow(
                settings.t('project_total_price'),
                project.income,
                settings,
                onSurface,
              ),
              _moneyRow(
                settings.t('project_advance'),
                project.receivedAmount,
                settings,
                onSurface,
              ),
              _moneyRow(
                settings.t('project_debt_left'),
                project.debtAmount,
                settings,
                project.hasDebt
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                settings.t('project_payments_history'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addPayment(context, settings),
              icon: const Icon(Icons.add),
              label: Text(settings.t('project_add_payment')),
            ),
          ],
        ),
        if (project.payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              settings.t('project_no_payments'),
              style: TextStyle(color: onSurface.withValues(alpha: 0.55)),
            ),
          )
        else
          ...project.payments.reversed.map((p) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${_formatMoney(p.amount)} ${settings.t('currency_somoni')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    DateFormat('d.MM.y', settings.intlLocaleCode).format(p.date),
                    if (p.note.trim().isNotEmpty) p.note.trim(),
                  ].join(' — '),
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(settings.t('project_mark_completed')),
          value: project.isCompleted,
          activeColor: AppColors.accent,
          onChanged: (_) => onToggleCompleted(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onDelete,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          icon: const Icon(Icons.delete_outline),
          label: Text(settings.t('project_delete')),
        ),
      ],
    );
  }

  Future<void> _addPayment(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('project_add_payment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: settings.t('project_payment_amount'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: settings.t('project_payment_note'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(settings.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(settings.t('save')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(
      amountCtrl.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) return;
    final payment = ProjectPayment(
      id: const Uuid().v4(),
      amount: amount,
      date: DateTime.now(),
      note: noteCtrl.text.trim(),
    );
    onChanged(
      project.copyWith(
        payments: [...project.payments, payment],
        receivedAmount: project.receivedAmount + amount,
      ),
    );
  }

  Widget _moneyRow(
    String label,
    double value,
    SettingsProvider settings,
    Color color, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '${_formatMoney(value)} ${settings.t('currency_somoni')}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: child,
    );
  }

  static String _formatMoney(double value) {
    final number = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < number.length; i++) {
      final reversedIndex = number.length - i;
      buffer.write(number[i]);
      if (reversedIndex > 1 && reversedIndex % 3 == 1) buffer.write(' ');
    }
    return buffer.toString();
  }
}

class _NotesTab extends StatefulWidget {
  const _NotesTab({required this.project, required this.onChanged});

  final ProjectModel project;
  final ValueChanged<ProjectModel> onChanged;

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final project = widget.project;
    final items = project.checklist;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: settings.t('project_checklist_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addItem(settings),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _addItem(settings),
                style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _shareWhatsApp(settings),
                icon: const Icon(Icons.send_outlined),
                label: Text(settings.t('project_send_whatsapp')),
              ),
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    settings.t('project_checklist_empty'),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return CheckboxListTile(
                      value: item.isDone,
                      title: Text(
                        item.text,
                        style: TextStyle(
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      onChanged: (v) {
                        final next = List<ProjectChecklistItem>.from(items);
                        next[index] = item.copyWith(isDone: v == true);
                        widget.onChanged(project.copyWith(checklist: next));
                      },
                      secondary: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          final next = List<ProjectChecklistItem>.from(items)
                            ..removeAt(index);
                          widget.onChanged(project.copyWith(checklist: next));
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _addItem(SettingsProvider settings) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final item = ProjectChecklistItem(id: const Uuid().v4(), text: text);
    widget.onChanged(
      widget.project.copyWith(
        checklist: [...widget.project.checklist, item],
      ),
    );
    _controller.clear();
  }

  void _shareWhatsApp(SettingsProvider settings) {
    final project = widget.project;
    final buf = StringBuffer();
    buf.writeln('${settings.t('project_materials_list')}: ${project.title}');
    if (project.client.trim().isNotEmpty) {
      buf.writeln('${settings.t('project_client')}: ${project.client}');
    }
    buf.writeln();
    for (final item in project.checklist) {
      buf.writeln('${item.isDone ? '✅' : '⬜'} ${item.text}');
    }
    launchWhatsApp(context, project.phone, message: buf.toString());
  }
}

class _SketchTab extends StatelessWidget {
  const _SketchTab({required this.project, required this.onChanged});

  final ProjectModel project;
  final ValueChanged<ProjectModel> onChanged;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final sketches = project.sketches;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final path = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const SketchBoardPage()),
                );
                if (path == null || path.isEmpty) return;
                final sketch = ProjectSketch(
                  id: const Uuid().v4(),
                  imagePath: path,
                  createdAt: DateTime.now(),
                );
                onChanged(
                  project.copyWith(sketches: [...project.sketches, sketch]),
                );
              },
              icon: const Icon(Icons.brush_outlined),
              label: Text(settings.t('project_new_sketch')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentContrastText,
              ),
            ),
          ),
        ),
        Expanded(
          child: sketches.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.brush_outlined,
                          size: 56,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          settings.t('project_sketches_empty'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            final path = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SketchBoardPage(),
                              ),
                            );
                            if (path == null || path.isEmpty) return;
                            final sketch = ProjectSketch(
                              id: const Uuid().v4(),
                              imagePath: path,
                              createdAt: DateTime.now(),
                            );
                            onChanged(
                              project.copyWith(
                                sketches: [...project.sketches, sketch],
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: Text(settings.t('project_new_sketch')),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.accentContrastText,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: sketches.length,
                  itemBuilder: (context, index) {
                    final sketch = sketches[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenGalleryScreen(
                                imageUrls:
                                    sketches.map((s) => s.imagePath).toList(),
                                initialIndex: index,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(sketch.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.black12,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              iconSize: 18,
                              color: Colors.white,
                              onPressed: () {
                                final next =
                                    List<ProjectSketch>.from(sketches)
                                      ..removeAt(index);
                                onChanged(project.copyWith(sketches: next));
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab({
    required this.project,
    required this.onChanged,
    required this.picker,
  });

  final ProjectModel project;
  final ValueChanged<ProjectModel> onChanged;
  final ImagePicker picker;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final images = project.galleryImages;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(settings.t('project_camera')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pick(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(settings.t('project_gallery')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentContrastText,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (project.beforeVideo != null || project.afterVideo != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (project.beforeVideo != null) ...[
                  ProjectVideoPlayer(videoPath: project.beforeVideo!),
                  const SizedBox(height: 12),
                ],
                if (project.afterVideo != null) ...[
                  ProjectVideoPlayer(videoPath: project.afterVideo!),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        Expanded(
          child: images.isEmpty
              ? Center(child: Text(settings.t('project_gallery_empty')))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final path = images[index];
                    return GestureDetector(
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
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Colors.black12),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (project.beforeImages.length >=
        ProjectStorageService.maxImagesPerProject) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('project_photo_limit_reached'))),
      );
      return;
    }
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    onChanged(
      project.copyWith(
        beforeImages: [...project.beforeImages, file.path],
      ),
    );
  }
}
