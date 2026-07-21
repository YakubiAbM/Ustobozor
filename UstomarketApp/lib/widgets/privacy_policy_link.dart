import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../providers/settings_provider.dart';

/// Ссылка на политику конфиденциальности (Google Play / App Store).
class PrivacyPolicyLink extends StatelessWidget {
  const PrivacyPolicyLink({super.key});

  static Future<void> open(BuildContext context) async {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть политику конфиденциальности')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return TextButton.icon(
      onPressed: () => open(context),
      icon: Icon(
        Icons.privacy_tip_outlined,
        size: 20,
        color: onSurface.withValues(alpha: 0.65),
      ),
      label: Text(
        settings.t('privacy_policy'),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
