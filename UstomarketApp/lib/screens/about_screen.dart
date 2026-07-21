import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../constants.dart';
import '../providers/settings_provider.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  static const _socialFields = [
    ('instagram_url', Icons.camera_alt_outlined, 'Instagram', null),
    ('tiktok_url', Icons.music_note_outlined, 'TikTok', null),
    ('telegram_url', Icons.send_outlined, 'Telegram', null),
    ('whatsapp_url', Icons.chat_outlined, 'WhatsApp', Color(0xFF25D366)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var years = 20;
    final socials = <String, dynamic>{};
    try {
      final response = await apiGet('/site/about');
      final body = json.decode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        years = (body['years_experience'] as num?)?.toInt() ?? 20;
        for (final field in _socialFields) {
          socials[field.$1] = body[field.$1];
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _data = {'years_experience': years, ...socials};
        _loading = false;
      });
    }
  }

  String? _normalizeUrl(String? raw) {
    var value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    return value;
  }

  Future<void> _openUrl(String? raw) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final url = _normalizeUrl(raw);
    if (url == null) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('about_us_link_error'))),
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.t('about_us_link_error'))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('about_us_link_error'))),
      );
    }
  }

  List<Widget> _buildSocialButtons(SettingsProvider settings) {
    final data = _data;
    final buttons = <Widget>[];

    for (final field in _socialFields) {
      final key = field.$1;
      final icon = field.$2;
      final label = field.$3;
      final iconColor = field.$4;
      final url = _normalizeUrl(data?[key] as String?);
      if (url == null) continue;

      buttons.add(
        _SocialButton(
          icon: icon,
          label: label,
          url: url,
          iconColor: iconColor,
          onTap: _openUrl,
        ),
      );
    }

    if (buttons.isEmpty) {
      return [
        Text(
          settings.t('about_us_social_empty'),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ];
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final data = _data;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.t('about_us')),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardBg : AppColors.cardBgLight,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark ? null : Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store_rounded, color: AppColors.accent, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  settings.t('about_us_company_name'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            settings.t('about_us_desc'),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            settings.t('about_us_years').replaceAll(
                                  '{years}',
                                  '${data?['years_experience'] ?? 20}',
                                ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      settings.t('about_us_social'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._buildSocialButtons(settings),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String url;
  final Color? iconColor;
  final Future<void> Function(String?) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.cardBg : AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onTap(url),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isDark ? null : Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.open_in_new, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
