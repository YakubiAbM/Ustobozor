import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../features/master_listing/pages/publish_master_listing_page.dart';
import '../features/service_requests/pages/create_service_request_page.dart';
import '../features/service_requests/pages/my_service_requests_page.dart';
import '../providers/app_mode_provider.dart';
import '../providers/client_auth_provider.dart';
import '../providers/master_auth_provider.dart';
import '../providers/settings_provider.dart';
import 'client_auth/client_login_phone_screen.dart';
import 'master_auth/master_login_phone_screen.dart';

/// Центральная кнопка «+»:
/// — мастер (режим мастер): публикация объявления;
/// — клиент не вошёл: экран как в профиле (войти / зарегистрироваться);
/// — клиент вошёл: создание заказа из каталога.
class PublishWorkScreen extends StatelessWidget {
  const PublishWorkScreen({super.key});

  bool _clientReady(ClientAuthProvider client) =>
      client.isLoggedIn &&
      client.accessToken != null &&
      client.accessToken!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final mode = Provider.of<AppModeProvider>(context);
    final master = Provider.of<MasterAuthProvider>(context);
    final client = Provider.of<ClientAuthProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMasterUi = mode.isMasterMode && master.isLoggedIn;

    if (isMasterUi) {
      return const PublishMasterListingPage(embedded: true);
    }

    // Как в профиле: без аккаунта заказчика — просим войти / зарегистрироваться.
    if (!_clientReady(client)) {
      return _GuestAuthScaffold(
        isDark: isDark,
        settings: settings,
        title: settings.t('sr_hub_client_title'),
      );
    }

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
                settings.t('sr_hub_client_title'),
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                settings.t('sr_hub_client_subtitle'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.secondary(isDark),
                ),
              ),
              const SizedBox(height: 28),
              _ActionCard(
                icon: Icons.add_circle_outline,
                title: settings.t('sr_create_title'),
                onTap: () async {
                  if (mode.isMasterMode) {
                    await mode.switchToClient();
                  }
                  if (!context.mounted) return;
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateServiceRequestPage(),
                    ),
                  );
                  if (created == true && context.mounted) {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyServiceRequestsPage(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.assignment_outlined,
                title: settings.t('sr_my_requests'),
                onTap: () async {
                  if (mode.isMasterMode) {
                    await mode.switchToClient();
                  }
                  if (!context.mounted) return;
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyServiceRequestsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка входа как на гостевом профиле.
class _GuestAuthScaffold extends StatelessWidget {
  const _GuestAuthScaffold({
    required this.isDark,
    required this.settings,
    required this.title,
  });

  final bool isDark;
  final SettingsProvider settings;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.screenHorizontalPadding,
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText(isDark),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                      decoration: BoxDecoration(
                        color: AppColors.card(isDark),
                        borderRadius: BorderRadius.circular(
                          AppLayout.cardBorderRadius,
                        ),
                        border: isDark
                            ? null
                            : Border.all(color: Colors.black12),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 64,
                            color: AppColors.accent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            settings.t('profile_guest_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: AppColors.secondary(isDark),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ClientLoginPhoneScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.person_outline, size: 22),
                              label: Text(settings.t('login_as_client')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.accentContrastText,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MasterLoginPhoneScreen(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.handyman_outlined,
                                size: 22,
                              ),
                              label: Text(settings.t('login_as_master')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    AppColors.primaryText(isDark),
                                side: BorderSide(
                                  color: AppColors.divider(isDark),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.cardBg : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
