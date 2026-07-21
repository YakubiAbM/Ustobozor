import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/master_auth_provider.dart';
import '../providers/settings_provider.dart';
import 'master_auth/master_login_phone_screen.dart';

/// Публикация работ мастером (MVP — заглушка с входом для мастера).
class PublishWorkScreen extends StatelessWidget {
  const PublishWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final master = Provider.of<MasterAuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffold(isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppLayout.screenHorizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                settings.t('publish_work_title'),
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                settings.t('publish_work_subtitle'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.secondary(isDark),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 44,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        master.isLoggedIn
                            ? settings.t('publish_work_coming_soon')
                            : settings.t('publish_work_login_hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.primaryText(isDark),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!master.isLoggedIn)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: AppColors.accentButtonStyle(),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MasterLoginPhoneScreen(),
                                ),
                              );
                            },
                            child: Text(settings.t('login_as_master')),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
