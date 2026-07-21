import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/settings_provider.dart';
import '../providers/master_auth_provider.dart';
import '../widgets/master_qr_code_card.dart';

/// Профиль мастера: как обычный профиль + код мастера (ID) + баллы. Трата баллов отключена.
class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key});

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  static const _logoutRed = Color(0xFFD74C4C);

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final master = Provider.of<MasterAuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;

    return MasterQrBrightnessScope(
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: onSurface,
        elevation: 0,
        title: Text(settings.t('profile'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await master.refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(settings.t('refresh')), behavior: SnackBarBehavior.floating),
                );
              }
            },
            tooltip: settings.t('refresh'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.accent,
                    child: Icon(Icons.handyman, color: AppColors.accentContrastText, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          master.masterName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          master.masterPhone,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                settings.t('master_your_code'),
                style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.8)),
              ),
              const SizedBox(height: 8),
              MasterQrCodeCard(
                code: master.masterCode ?? '',
                size: 220,
                onTap: master.masterCode != null
                    ? () => showMasterQrFullScreen(
                          context,
                          code: master.masterCode!,
                          title: settings.t('master_your_code'),
                        )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                settings.t('master_code_hint'),
                style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.6), height: 1.3),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.masterStatsGradientStart,
                      AppColors.accent,
                      AppColors.masterStatsGradientEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.diamond, color: AppColors.accentContrastText, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          settings.t('master_balance'),
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.accentContrastText.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (master.points > 0)
                      Text(
                        '${master.points} ${settings.t('master_points_unit')}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentContrastText,
                        ),
                      )
                    else
                      Text(
                        settings.t('master_buy_to_get_points'),
                        style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.3),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildAnnouncementBlock(context, settings, isDark, onSurface),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: _logoutRed,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () async {
                      await master.logout();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            settings.t('logout_master'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.logout, color: Colors.white, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildAnnouncementBlock(BuildContext context, SettingsProvider settings, bool isDark, Color onSurface) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, color: AppColors.accent, size: 28),
              const SizedBox(width: 12),
              Text(
                settings.t('announcement'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            settings.t('announcement_desc'),
            style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.85), height: 1.4),
          ),
        ],
      ),
    );
  }
}
