import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../api_client.dart';
import '../features/projects/pages/my_projects_page.dart';
import '../models/order.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/master_auth_provider.dart';
import '../providers/client_auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/notifications_provider.dart';
// import '../services/push_notification_service.dart'; // Push пока отключён
import 'invoice_screen.dart';
import 'master_auth/master_login_phone_screen.dart';
import 'client_auth/client_login_phone_screen.dart';
import 'master_notifications_screen.dart';
import 'about_screen.dart';
import '../widgets/master_qr_code_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    nav.addListener(_onNavChanged);
  }

  Future<void> _refreshProfileData() async {
    final master = Provider.of<MasterAuthProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (master.isLoggedIn) {
      // await master.refreshPointsFromServer(); // баллы временно отключены
      if (mounted) setState(() {});
      if (mounted)
        Provider.of<NotificationsProvider>(
          context,
          listen: false,
        ).refreshUnreadCount(master.accessToken);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('refresh')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onNavChanged() {
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    if (!nav.requestProfileRefresh || !mounted) return;
    nav.clearRequestProfileRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshProfileData();
    });
  }

  @override
  void dispose() {
    Provider.of<NavigationProvider>(
      context,
      listen: false,
    ).removeListener(_onNavChanged);
    _scrollController.dispose();
    super.dispose();
  }

  static const Color _whatsappTeal = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final user = Provider.of<UserProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final menuIconColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final hPad = AppLayout.screenHorizontalPadding;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshProfileData,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    settings.t('profile'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.accent,
                      child: Icon(Icons.person, color: AppColors.accentContrastText, size: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.phone,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Consumer<MasterAuthProvider>(
                  builder: (context, master, _) {
                    if (master.isLoggedIn) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildClientAuthBlock(
                          context,
                          settings,
                          isDark,
                          onSurface,
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
                _buildMasterAuthBlock(
                  context,
                  settings,
                  isDark,
                  onSurface,
                ),
                const SizedBox(height: 20),
                _buildMenuSection(
                  isDark: isDark,
                  onSurface: onSurface,
                  iconColor: menuIconColor,
                  items: [
                    _ProfileMenuItemData(
                      icon: Icons.inventory_2_outlined,
                      title: settings.t('my_orders'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrdersHistoryScreen(phone: user.fullPhone),
                        ),
                      ),
                    ),
                    _ProfileMenuItemData(
                      icon: Icons.folder_outlined,
                      title: settings.t('my_projects'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyProjectsPage(),
                        ),
                      ),
                    ),
                    _ProfileMenuItemData(
                      icon: Icons.location_on_outlined,
                      title: settings.t('delivery_addresses'),
                      onTap: () => _showAddressSheet(context, settings, user),
                    ),
                    _ProfileMenuItemData(
                      icon: Icons.info_outline,
                      title: settings.t('about_us'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMenuSection(
                  isDark: isDark,
                  onSurface: onSurface,
                  iconColor: menuIconColor,
                  items: [
                    _ProfileMenuItemData(
                      icon: Icons.language_outlined,
                      title: settings.t('app_language'),
                      trailingText: settings.langCode == 'tj'
                          ? settings.t('language_tj')
                          : settings.t('language_ru'),
                      onTap: () => _showLanguageSheet(context, settings),
                    ),
                    _ProfileMenuItemData(
                      icon: isDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      title: settings.t('dark_theme'),
                      trailingWidget: SwitchTheme(
                        data: SwitchThemeData(
                          thumbColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.accent;
                            }
                            return null;
                          }),
                          trackColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.accent.withValues(alpha: 0.35);
                            }
                            return null;
                          }),
                        ),
                        child: Switch(
                          value: settings.isDarkMode,
                          onChanged: settings.toggleTheme,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMenuSection(
                  isDark: isDark,
                  onSurface: onSurface,
                  iconColor: menuIconColor,
                  items: [
                    _ProfileMenuItemData(
                      icon: Icons.chat_outlined,
                      title: settings.t('support'),
                      iconColor: _whatsappTeal,
                      onTap: () async {
                        final uri = Uri.parse('https://wa.me/+992872148008');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final masterAuth = Provider.of<MasterAuthProvider>(
                        context,
                        listen: false,
                      );
                      await user.clearUser();
                      if (masterAuth.isLoggedIn) await masterAuth.logout();
                    },
                    child: Text(
                      settings.t('exit'),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppLayout.cardBorderRadius),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                settings.t('app_language'),
                style: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
              ),
            ),
            ListTile(
              leading: settings.langCode == 'ru'
                  ? Icon(Icons.check, color: AppColors.accent)
                  : const SizedBox(width: 24),
              title: Text(settings.t('language_ru')),
              onTap: () {
                settings.setLanguage('ru');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: settings.langCode == 'tj'
                  ? Icon(Icons.check, color: AppColors.accent)
                  : const SizedBox(width: 24),
              title: Text(settings.t('language_tj')),
              onTap: () {
                settings.setLanguage('tj');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddressSheet(
    BuildContext context,
    SettingsProvider settings,
    UserProvider user,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final controller = TextEditingController(text: user.address);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppLayout.cardBorderRadius),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppLayout.screenHorizontalPadding,
          right: AppLayout.screenHorizontalPadding,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              settings.t('delivery_addresses'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                hintText: settings.t('address_hint'),
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: isDark ? AppColors.inputBg : AppColors.inputBgLight,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppLayout.cardBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await user.updateAddress(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentContrastText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppLayout.cardBorderRadius),
                ),
              ),
              child: Text(settings.t('confirm')),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  Widget _buildMenuSection({
    required bool isDark,
    required Color onSurface,
    required Color iconColor,
    required List<_ProfileMenuItemData> items,
  }) {
    final bg = isDark ? AppColors.cardBg : AppColors.cardBgLight;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
        border: isDark ? null : Border.all(color: Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _buildMenuTile(
              item: items[i],
              onSurface: onSurface,
              defaultIconColor: iconColor,
            ),
            if (i < items.length - 1)
              Divider(height: 1, thickness: 1, color: dividerColor, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required _ProfileMenuItemData item,
    required Color onSurface,
    required Color defaultIconColor,
  }) {
    final tileIconColor = item.iconColor ?? defaultIconColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(item.icon, color: tileIconColor, size: 22),
        title: Text(
          item.title,
          style: TextStyle(color: onSurface, fontSize: 16),
        ),
        trailing: item.trailingWidget ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.trailingText != null)
                  Text(
                    item.trailingText!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                if (item.trailingText != null) const SizedBox(width: 4),
                if (item.onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
              ],
            ),
        onTap: item.onTap,
      ),
    );
  }

  Widget _buildClientAuthBlock(
    BuildContext context,
    SettingsProvider settings,
    bool isDark,
    Color onSurface,
  ) {
    final client = Provider.of<ClientAuthProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
        border: isDark ? null : Border.all(color: Colors.black12),
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
      child: client.isLoggedIn
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.accent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.t('logged_in_as_client'),
                            style: TextStyle(
                              fontSize: 14,
                              color: onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            client.clientName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          if (client.clientPhone.isNotEmpty)
                            Text(
                              client.clientPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await context.read<ClientAuthProvider>().logout();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(settings.t('logout_client'))),
                      );
                    },
                    child: Text(settings.t('logout_client')),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  settings.t('client_phone_prompt'),
                  style: TextStyle(
                    fontSize: 14,
                    color: onSurface.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ClientLoginPhoneScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.login, size: 20),
                    label: Text(settings.t('login_client')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentContrastText,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMasterAuthBlock(
    BuildContext context,
    SettingsProvider settings,
    bool isDark,
    Color onSurface,
  ) {
    final master = Provider.of<MasterAuthProvider>(context);
    if (master.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Provider.of<NotificationsProvider>(
          context,
          listen: false,
        ).refreshUnreadCount(master.accessToken);
        // PushNotificationService.registerTokenIfNeeded(master.accessToken); // Push пока отключён
      });
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
        border: isDark ? null : Border.all(color: Colors.black12),
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
      child: master.isLoggedIn
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.accent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.t('logged_in_as_master'),
                            style: TextStyle(
                              fontSize: 14,
                              color: onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            master.masterName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildMasterBarcode(
                  context,
                  master,
                  settings,
                  onSurface,
                  isDark,
                ),
                if (kMasterPointsEnabled) ...[
                  const SizedBox(height: 14),
                  Consumer<MasterAuthProvider>(
                    builder: (context, master, _) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
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
                        borderRadius:
                            BorderRadius.circular(AppLayout.cardBorderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.diamond, color: AppColors.accentContrastText, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            settings.t('master_balance'),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.accentContrastText.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (master.points > 0)
                            Text(
                              '${master.points} ${settings.t('master_points_unit')}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentContrastText,
                              ),
                            )
                          else
                            Text(
                              settings.t('master_buy_to_get_points'),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.accentContrastText.withValues(alpha: 0.75),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (master.hasDebt) ...[
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(settings.t('master_debt')),
                            content: Text(
                              '${settings.t('master_debt')}: ${master.debt.toStringAsFixed(0)} ${settings.t('master_debt_tjs')}',
                              style: TextStyle(fontSize: 16, color: onSurface),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.inputBg
                              : AppColors.inputBgLight,
                          borderRadius:
                              BorderRadius.circular(AppLayout.cardBorderRadius),
                          border: Border.all(
                            color: AppColors.orange.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                settings.t('master_debt_button'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '${master.debt.toStringAsFixed(0)} ${settings.t('master_debt_tjs')}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.orange,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: onSurface.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Consumer<NotificationsProvider>(
                  builder: (context, notif, _) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MasterNotificationsScreen(),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                color: onSurface.withOpacity(0.8),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                settings.t('notifications_title'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                              ),
                              const Spacer(),
                              if (notif.unreadCount > 0)
                                Badge(
                                  label: Text('${notif.unreadCount}'),
                                  backgroundColor: AppColors.accent,
                                  child: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.chevron_right,
                                  color: onSurface.withOpacity(0.5),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.accent.withOpacity(0.2),
                      child: Icon(
                        Icons.handyman,
                        color: AppColors.accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.t('you_master_banner'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            settings.t('you_master_add_phone'),
                            style: TextStyle(
                              fontSize: 13,
                              color: onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MasterLoginPhoneScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.login, size: 20),
                    label: Text(settings.t('login_master')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentContrastText,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMasterBarcode(
    BuildContext context,
    MasterAuthProvider master,
    SettingsProvider settings,
    Color onSurface,
    bool isDark,
  ) {
    final code = master.masterCode;
    final hasCode = code != null && code.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settings.t('loyalty_barcode'),
          style: TextStyle(
            fontSize: 14,
            color: onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        hasCode
            ? MasterQrCodeCard(
                code: code,
                compact: true,
                size: 200,
                onTap: () => showMasterQrFullScreen(
                  context,
                  code: code,
                  title: settings.t('loyalty_barcode'),
                ),
              )
            : _barcodePlaceholder(settings, isDark: isDark),
      ],
    );
  }

  Widget _barcodePlaceholder(
    SettingsProvider settings, {
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          settings.t('barcode_contact_admin'),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondary : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

}

class _ProfileMenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final String? trailingText;
  final Widget? trailingWidget;

  const _ProfileMenuItemData({
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.trailingText,
    this.trailingWidget,
  });
}

class OrdersHistoryScreen extends StatefulWidget {
  final String phone;
  const OrdersHistoryScreen({super.key, required this.phone});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final masterAuth = Provider.of<MasterAuthProvider>(
        context,
        listen: false,
      );
      // JWT хранится в SecureTokenStorage (Keychain / Keystore).
      final token = masterAuth.accessToken?.trim();
      final bool useToken = token != null && token.isNotEmpty;
      final authToken = token ?? '';
      final response = useToken
          ? await apiGetWithBearer('/orders/history', authToken)
          : await apiGet(
              '/orders/history',
              queryParameters: {'phone': widget.phone},
            );
      final String body = utf8.decode(response.bodyBytes);
      if (response.statusCode == 200) {
        final decoded = json.decode(body);
        List<dynamic> data = [];
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          final map = decoded as Map<String, dynamic>;
          if (map['orders'] is List)
            data = map['orders'] as List;
          else if (map['data'] is List)
            data = map['data'] as List;
          else if (map['results'] is List)
            data = map['results'] as List;
        }
        if (mounted) {
          setState(() {
            _orders = [];
            for (final e in data) {
              try {
                final m = e is Map<String, dynamic>
                    ? e
                    : Map<String, dynamic>.from(e as Map);
                _orders.add(Order.fromJson(m));
              } catch (_) {}
            }
            _loading = false;
          });
        }
      } else {
        if (mounted)
          setState(() {
            _loading = false;
            _error = response.statusCode == 404
                ? 'Адрес для списка заказов не найден (404). На бэкенде нужен GET, например: /orders?phone= или /orders/history?phone='
                : response.statusCode == 405
                ? 'Метод GET не разрешён (405). Добавьте на сервер GET для списка заказов по phone.'
                : 'Ошибка: ${response.statusCode}';
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          String msg = e
              .toString()
              .replaceFirst(RegExp(r'^Exception:\s*'), '')
              .replaceFirst(RegExp(r'^ApiClientException:\s*'), '');
          if (msg.contains('Not authenticated') ||
              msg.contains('401') ||
              msg.contains('токен') ||
              msg.contains('token')) {
            msg =
                'История заказов доступна после входа как мастер. Войдите в профиле по номеру телефона.';
          }
          _error = msg.isNotEmpty
              ? msg
              : 'Не удалось загрузить заказы. Проверьте интернет и адрес сервера.';
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  static String _orderStatusText(String status, SettingsProvider settings) {
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        return 'Выполнен';
      case 'cancelled':
      case 'canceled':
        return 'Отменён';
      case 'new':
      case 'in_progress':
      case 'processing':
      default:
        return settings.t('order_in_processing');
    }
  }

  static Color _orderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  static String _formatOrderDate(String raw) {
    if (raw.isEmpty) return raw;
    try {
      final s = raw.replaceFirst('T', ' ').trim();
      final parts = s.split(RegExp(r'[\s\-:T.]'));
      if (parts.length >= 5) {
        final y = parts[0];
        final m = parts[1].padLeft(2, '0');
        final d = parts[2].padLeft(2, '0');
        final h = parts[3].padLeft(2, '0');
        final min = parts[4].padLeft(2, '0');
        return '$d.$m.$y $h:$min';
      }
      if (parts.length >= 3) {
        final y = parts[0];
        final m = parts[1].padLeft(2, '0');
        final d = parts[2].padLeft(2, '0');
        return '$d.$m.$y';
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          settings.t('my_orders'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 56,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _loadOrders,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          : _orders.isEmpty
          ? Center(
              child: Text(
                'Заказов пока нет',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadOrders,
              color: AppColors.accent,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 80),
                itemCount: _orders.length,
                itemBuilder: (ctx, i) {
                  final order = _orders[i];
                  final orderNum = order.number.length >= 6
                      ? order.number
                      : order.number.padLeft(6, '0');
                  final statusColor = _orderStatusColor(order.status);
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceScreen(order: order),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF374151)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Заказ №$orderNum',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatOrderDate(order.date),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.receipt_long,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      settings.t('waybill').toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _orderStatusText(order.status, settings),
                              style: TextStyle(
                                fontSize: 13,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${order.total.toInt()} смн',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
