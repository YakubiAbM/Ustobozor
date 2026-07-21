import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';

class AddProjectPage extends StatefulWidget {
  const AddProjectPage({super.key, this.initialProject});

  final ProjectModel? initialProject;

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _titleController = TextEditingController();
  final _clientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _incomeController = TextEditingController();
  final _receivedAmountController = TextEditingController();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();

  late DateTime _selectedDate;
  late List<String> _beforeImages;
  late List<String> _afterImages;
  String? _beforeVideo;
  String? _afterVideo;
  bool _saving = false;

  bool get _isEditing => widget.initialProject != null;

  @override
  void initState() {
    super.initState();
    final project = widget.initialProject;
    _titleController.text = project?.title ?? '';
    _clientController.text = project?.client ?? '';
    _phoneController.text = project?.phone ?? '';
    _incomeController.text = project == null
        ? ''
        : _formatIncome(project.income);
    _receivedAmountController.text = project == null
        ? ''
        : _formatIncome(project.receivedAmount);
    _noteController.text = project?.note ?? '';
    _selectedDate = project?.date ?? DateTime.now();
    _beforeImages = List<String>.from(project?.beforeImages ?? const []);
    _afterImages = List<String>.from(project?.afterImages ?? const []);
    _beforeVideo = project?.beforeVideo;
    _afterVideo = project?.afterVideo;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _clientController.dispose();
    _phoneController.dispose();
    _incomeController.dispose();
    _receivedAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t(_isEditing ? 'projects_edit' : 'projects_new')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _inputLabel(settings.t('project_title')),
              const SizedBox(height: 8),
              _textField(
                controller: _titleController,
                hint: settings.t('project_title_hint'),
              ),
              const SizedBox(height: 16),
              _inputLabel(settings.t('project_client')),
              const SizedBox(height: 8),
              _textField(
                controller: _clientController,
                hint: settings.t('project_client_hint'),
              ),
              const SizedBox(height: 16),
              _inputLabel(settings.t('project_client_phone')),
              const SizedBox(height: 8),
              _textField(
                controller: _phoneController,
                hint: settings.t('project_client_phone_hint'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _inputLabel(settings.t('project_income')),
              const SizedBox(height: 8),
              _textField(
                controller: _incomeController,
                hint: settings.t('project_income_hint'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              _inputLabel(settings.t('project_received')),
              const SizedBox(height: 8),
              _textField(
                controller: _receivedAmountController,
                hint: settings.t('project_received_hint'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              _inputLabel(settings.t('project_date')),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat(
                          'd MMMM y',
                          settings.intlLocaleCode,
                        ).format(_selectedDate),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _inputLabel(settings.t('project_note')),
              const SizedBox(height: 8),
              _textField(
                controller: _noteController,
                hint: settings.t('project_note_hint'),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildImageSection(
                title: settings.t('project_before_photos'),
                images: _beforeImages,
                isDark: isDark,
                onAdd: () => _showImageSourceSheet(isBeforeImages: true),
                onRemove: (index) =>
                    setState(() => _beforeImages.removeAt(index)),
              ),
              const SizedBox(height: 16),
              _buildVideoSection(
                title: settings.t('project_before_video'),
                videoPath: _beforeVideo,
                isDark: isDark,
                onAdd: () => _showVideoSourceSheet(isBeforeVideo: true),
                onRemove: () => setState(() => _beforeVideo = null),
              ),
              const SizedBox(height: 16),
              _buildImageSection(
                title: settings.t('project_after_photos'),
                images: _afterImages,
                isDark: isDark,
                onAdd: () => _showImageSourceSheet(isBeforeImages: false),
                onRemove: (index) =>
                    setState(() => _afterImages.removeAt(index)),
              ),
              const SizedBox(height: 16),
              _buildVideoSection(
                title: settings.t('project_after_video'),
                videoPath: _afterVideo,
                isDark: isDark,
                onAdd: () => _showVideoSourceSheet(isBeforeVideo: false),
                onRemove: () => setState(() => _afterVideo = null),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveProject,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentContrastText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    settings.t('project_save'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection({
    required String title,
    required List<String> images,
    required bool isDark,
    required VoidCallback onAdd,
    required ValueChanged<int> onRemove,
  }) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final reachedLimit =
        images.length >= ProjectStorageService.maxImagesPerProject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputLabel(title),
        if (!reachedLimit) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(settings.t('project_add_photo')),
          ),
        ],
        const SizedBox(height: 12),
        if (images.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final imagePath = images[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(imagePath),
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 92,
                          height: 92,
                          color: isDark ? AppColors.cardBg : AppColors.bgLight,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemove(index),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        if (images.isEmpty && reachedLimit)
          Text(
            settings.t('project_photo_limit_reached'),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          )
        else if (images.isEmpty)
          Text(
            settings.t('project_photo_limit'),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoSection({
    required String title,
    required String? videoPath,
    required bool isDark,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputLabel(title),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.video_call_outlined),
          label: Text(
            videoPath == null
                ? settings.t('project_add_video')
                : settings.t('project_replace_video'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              const Icon(Icons.videocam_outlined, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  videoPath == null
                      ? settings.t('project_video_not_added')
                      : settings.t('project_video_selected'),
                ),
              ),
              if (videoPath != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? AppColors.cardBg : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: Locale(settings.materialLocaleCode),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showImageSourceSheet({required bool isBeforeImages}) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(settings.t('project_camera')),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromCamera(isBeforeImages: isBeforeImages);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(settings.t('project_gallery')),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFromGallery(isBeforeImages: isBeforeImages);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showVideoSourceSheet({required bool isBeforeVideo}) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  settings.t('project_pick_video_source'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: Text(settings.t('project_camera')),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickVideo(
                    isBeforeVideo: isBeforeVideo,
                    source: ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: Text(settings.t('project_gallery')),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickVideo(
                    isBeforeVideo: isBeforeVideo,
                    source: ImageSource.gallery,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera({required bool isBeforeImages}) async {
    final targetList = isBeforeImages ? _beforeImages : _afterImages;
    if (targetList.length >= ProjectStorageService.maxImagesPerProject) return;
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;
    setState(() {
      targetList.add(image.path);
    });
  }

  Future<void> _pickFromGallery({required bool isBeforeImages}) async {
    final targetList = isBeforeImages ? _beforeImages : _afterImages;
    final remaining =
        ProjectStorageService.maxImagesPerProject - targetList.length;
    if (remaining <= 0) return;

    final images = await _picker.pickMultiImage(imageQuality: 85);
    if (!mounted || images.isEmpty) return;

    setState(() {
      targetList.addAll(images.take(remaining).map((file) => file.path));
    });
  }

  Future<void> _pickVideo({
    required bool isBeforeVideo,
    required ImageSource source,
  }) async {
    final video = await _picker.pickVideo(source: source);
    if (video == null || !mounted) return;
    setState(() {
      if (isBeforeVideo) {
        _beforeVideo = video.path;
      } else {
        _afterVideo = video.path;
      }
    });
  }

  Future<void> _saveProject() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage(settings.t('project_enter_title_error'));
      return;
    }

    final income = double.tryParse(
      _incomeController.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );
    if (income == null || income <= 0) {
      _showMessage(settings.t('project_income_error'));
      return;
    }

    final receivedAmount =
        double.tryParse(
          _receivedAmountController.text
              .trim()
              .replaceAll(' ', '')
              .replaceAll(',', '.'),
        ) ??
        0;
    if (receivedAmount < 0) {
      _showMessage(settings.t('project_received_error'));
      return;
    }

    setState(() => _saving = true);
    try {
      final project = ProjectModel(
        id: widget.initialProject?.id ?? const Uuid().v4(),
        title: title,
        client: _clientController.text.trim(),
        phone: _phoneController.text.trim(),
        income: income,
        receivedAmount: receivedAmount,
        date: _selectedDate,
        note: _noteController.text.trim(),
        beforeImages: List<String>.from(_beforeImages),
        afterImages: List<String>.from(_afterImages),
        beforeVideo: _beforeVideo,
        afterVideo: _afterVideo,
      );

      if (_isEditing) {
        await ProjectStorageService.instance.updateProject(project);
      } else {
        await ProjectStorageService.instance.addProject(project);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on StateError catch (error) {
      _showMessage(error.message.toString());
    } catch (_) {
      _showMessage(settings.t('project_save_error'));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatIncome(double income) {
    if (income == income.roundToDouble()) {
      return income.toInt().toString();
    }
    return income.toStringAsFixed(2);
  }
}
