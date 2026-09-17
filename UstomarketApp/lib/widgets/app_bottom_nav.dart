import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/app_mode_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';

/// Нижняя навигация: Главная, Мастера/Лента, +, Материалы, Профиль.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final mode = Provider.of<AppModeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final materialsSelected =
        currentIndex == NavigationProvider.tabMaterials ||
        currentIndex == NavigationProvider.tabCart;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.scaffold(isDark),
        border: Border(top: BorderSide(color: AppColors.divider(isDark), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: settings.t('home'),
                selected: currentIndex == NavigationProvider.tabHome,
                onTap: () => onTap(NavigationProvider.tabHome),
              ),
              _NavItem(
                icon: mode.isMasterMode
                    ? Icons.dynamic_feed_outlined
                    : Icons.handyman_outlined,
                activeIcon: mode.isMasterMode
                    ? Icons.dynamic_feed
                    : Icons.handyman,
                label: mode.isMasterMode
                    ? settings.t('sr_feed_short')
                    : settings.t('masters'),
                selected: currentIndex == NavigationProvider.tabMasters,
                onTap: () => onTap(NavigationProvider.tabMasters),
              ),
              _PlusNavItem(
                selected: currentIndex == NavigationProvider.tabPublish,
                onTap: () => onTap(NavigationProvider.tabPublish),
              ),
              _NavItem(
                icon: mode.isMasterMode
                    ? Icons.folder_outlined
                    : Icons.storefront_outlined,
                activeIcon: mode.isMasterMode
                    ? Icons.folder
                    : Icons.storefront,
                label: mode.isMasterMode
                    ? settings.t('sr_crm_short')
                    : settings.t('materials'),
                selected: materialsSelected ||
                    (mode.isMasterMode &&
                        currentIndex == NavigationProvider.tabMaterials),
                onTap: () => onTap(NavigationProvider.tabMaterials),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: settings.t('profile'),
                selected: currentIndex == NavigationProvider.tabProfile,
                onTap: () => onTap(NavigationProvider.tabProfile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.secondary(
      Theme.of(context).brightness == Brightness.dark,
    );

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: AppColors.accent,
              textColor: AppColors.accentContrastText,
              child: Icon(selected ? activeIcon : icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusNavItem extends StatelessWidget {
  const _PlusNavItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.orange : AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: AppColors.accentContrastText,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
