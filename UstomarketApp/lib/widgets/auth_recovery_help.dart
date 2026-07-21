import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../providers/settings_provider.dart';

const Color _whatsappTeal = Color(0xFF25D366);

/// Подсказка: восстановление аккаунта через администратора + WhatsApp.
void showAuthRecoverySheet(BuildContext context, SettingsProvider settings) {
  final theme = Theme.of(context);
  final onSurface = theme.colorScheme.onSurface;
  final isDark = theme.brightness == Brightness.dark;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              settings.t('auth_recovery_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              settings.t('auth_recovery_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: onSurface.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.parse(kSupportWhatsAppUri);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.chat, color: Colors.white),
              label: Text(settings.t('auth_recovery_whatsapp')),
              style: FilledButton.styleFrom(
                backgroundColor: _whatsappTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                settings.t('close'),
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Кнопка «Восстановление» под формой входа.
class AuthRecoveryLink extends StatelessWidget {
  const AuthRecoveryLink({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return TextButton.icon(
      onPressed: () => showAuthRecoverySheet(context, settings),
      icon: Icon(
        Icons.lock_reset_outlined,
        size: 20,
        color: onSurface.withValues(alpha: 0.65),
      ),
      label: Text(
        settings.t('auth_recovery_btn'),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
