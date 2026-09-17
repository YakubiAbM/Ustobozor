import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/master_auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../screens/master_auth/master_login_phone_screen.dart';
import '../../../widgets/app_cached_image.dart';
import '../services/master_listing_api.dart';

const _fallbackCategories = [
  'Сантехник',
  'Электрик',
  'Маляр',
  'Плиточник',
  'Сварщик',
  'Евроремонт',
  'Разнорабочий',
  'Алюкобонд',
];

/// Форма объявления мастера: название, категория, фото → модерация.
class PublishMasterListingPage extends StatefulWidget {
  const PublishMasterListingPage({super.key, this.embedded = false});

  /// Если true — без собственного AppBar (вкладка «+»).
  final bool embedded;

  @override
  State<PublishMasterListingPage> createState() =>
      _PublishMasterListingPageState();
}

class _PublishMasterListingPageState extends State<PublishMasterListingPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _experience = TextEditingController();

  List<String> _categories = List.of(_fallbackCategories);
  String _category = _fallbackCategories.first;
  XFile? _photo;
  final _portfolio = <XFile>[];
  MasterListing? _listing;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _loadedForToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token =
        Provider.of<MasterAuthProvider>(context).accessToken ?? '';
    if (token.isNotEmpty && token != _loadedForToken && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _city.dispose();
    _experience.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final master = Provider.of<MasterAuthProvider>(context, listen: false);
    final token = master.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _listing = null;
        _loadedForToken = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await MasterListingApi.instance.getMyListing(token);
      if (!mounted) return;
      final listing = result.listing;
      final cats = result.categories.isNotEmpty
          ? result.categories
          : _fallbackCategories;
      String cat = cats.first;
      if (listing != null && listing.categories.isNotEmpty) {
        final existing = listing.categories.first;
        if (!cats.contains(existing)) {
          cats.insert(0, existing);
        }
        cat = existing;
      }
      final rawName = listing?.name ?? '';
      _name.text = (rawName.isNotEmpty && rawName != 'Новый мастер')
          ? rawName
          : master.masterName;
      if (_name.text == 'Новый мастер') _name.clear();
      _desc.text = listing?.description ?? '';
      _city.text = listing?.city ?? '';
      _experience.text =
          (listing?.experience ?? 0) > 0 ? '${listing!.experience}' : '';
      setState(() {
        _categories = cats;
        _category = cat;
        _listing = listing;
        _loading = false;
        _photo = null;
        _loadedForToken = token;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadedForToken = token;
      });
    }
  }

  Future<void> _pickMainPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null) return;
    setState(() => _photo = file);
  }

  Future<void> _pickPortfolio() async {
    if (_portfolio.length >= 6) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (file == null) return;
    setState(() => _portfolio.add(file));
  }

  Future<void> _submit() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final master = Provider.of<MasterAuthProvider>(context, listen: false);
    final token = master.accessToken;
    if (token == null || token.isEmpty) return;

    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('ml_name_required'))),
      );
      return;
    }
    final hasExistingPhoto =
        (_listing?.image != null && _listing!.image.isNotEmpty);
    if (_photo == null && !hasExistingPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('ml_photo_required'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String photoB64 = '';
      if (_photo != null) {
        photoB64 = base64Encode(await File(_photo!.path).readAsBytes());
      } else if (!hasExistingPhoto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.t('ml_photo_required'))),
        );
        setState(() => _saving = false);
        return;
      }

      final portfolioB64 = <String>[];
      for (final p in _portfolio) {
        portfolioB64.add(base64Encode(await File(p.path).readAsBytes()));
      }
      final exp = int.tryParse(_experience.text.trim());

      final updated = await MasterListingApi.instance.submit(
        token: token,
        name: name,
        category: _category,
        photoBase64: photoB64,
        description: _desc.text.trim(),
        city: _city.text.trim(),
        experience: exp,
        portfolioBase64: portfolioB64,
      );
      if (!mounted) return;
      setState(() {
        _listing = updated;
        _photo = null;
        _portfolio.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('ml_sent_moderation'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${settings.t('ml_save_error')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _statusColor(String status, bool isDark) {
    switch (status) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFD97706);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return AppColors.secondary(isDark);
    }
  }

  String _statusLabel(SettingsProvider settings, String status) {
    switch (status) {
      case 'approved':
        return settings.t('ml_status_approved');
      case 'pending':
        return settings.t('ml_status_pending');
      case 'rejected':
        return settings.t('ml_status_rejected');
      default:
        return settings.t('ml_status_draft');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final master = Provider.of<MasterAuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loggedIn = master.isLoggedIn;

    final body = !loggedIn
        ? _LoginGate(settings: settings)
        : _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    if (_listing != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            _listing!.moderationStatus,
                            isDark,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _statusColor(
                              _listing!.moderationStatus,
                              isDark,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusLabel(
                                settings,
                                _listing!.moderationStatus,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _statusColor(
                                  _listing!.moderationStatus,
                                  isDark,
                                ),
                              ),
                            ),
                            if (_listing!.moderationNote.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _listing!.moderationNote,
                                style: TextStyle(
                                  color: AppColors.secondary(isDark),
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (_listing!.moderationStatus == 'approved') ...[
                              const SizedBox(height: 6),
                              Text(
                                settings.t('ml_visible_in_catalog'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondary(isDark),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      settings.t('ml_title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      settings.t('ml_subtitle'),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.secondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${settings.t('ml_name')} *',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      decoration: InputDecoration(
                        hintText: settings.t('ml_name_hint'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${settings.t('ml_category')} *',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _categories.contains(_category)
                          ? _category
                          : _categories.first,
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${settings.t('ml_photo')} *',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickMainPhoto,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.card(isDark),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider(isDark)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _photo != null
                            ? Image.file(
                                File(_photo!.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : (_listing?.image.isNotEmpty == true)
                                ? AppCachedImage(
                                    imagePath: _listing!.image,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 160,
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo_outlined,
                                          color: AppColors.secondary(isDark),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          settings.t('ml_photo_tap'),
                                          style: TextStyle(
                                            color: AppColors.secondary(isDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settings.t('ml_optional'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _city,
                      decoration: InputDecoration(
                        labelText: settings.t('ml_city'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _experience,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: settings.t('ml_experience'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _desc,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: settings.t('ml_description'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      settings.t('ml_portfolio'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _portfolio.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_portfolio[i].path),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      setState(() => _portfolio.removeAt(i)),
                                ),
                              ),
                            ],
                          ),
                        if (_portfolio.length < 6)
                          InkWell(
                            onTap: _pickPortfolio,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.divider(isDark),
                                ),
                              ),
                              child: Icon(
                                Icons.add,
                                color: AppColors.secondary(isDark),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(settings.t('ml_submit')),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: AppColors.scaffold(isDark),
        body: SafeArea(child: body),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold(isDark),
      appBar: AppBar(title: Text(settings.t('ml_title')), centerTitle: true),
      body: body,
    );
  }
}

class _LoginGate extends StatelessWidget {
  const _LoginGate({required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              settings.t('ml_need_login'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MasterLoginPhoneScreen(),
                  ),
                );
              },
              child: Text(settings.t('login_as_master')),
            ),
          ],
        ),
      ),
    );
  }
}
