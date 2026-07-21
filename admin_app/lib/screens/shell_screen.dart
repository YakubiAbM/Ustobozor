import 'package:flutter/material.dart';

import '../api/admin_auth_api.dart';
import '../constants.dart';
import '../models/admin_session.dart';
import '../providers/theme_provider.dart';
import 'tabs/admins_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/kassa_tab.dart';
import 'tabs/masters_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/products_tab.dart';

class _ShellTab {
  const _ShellTab({
    required this.scope,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.builder,
  });

  final String scope;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget Function() builder;
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    required this.session,
    required this.onLogout,
    required this.themeProvider,
  });

  final AdminSession session;
  final VoidCallback onLogout;
  final AdminThemeProvider themeProvider;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  static const _allTabs = [
    _ShellTab(
      scope: 'dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Главная',
      builder: DashboardTab.new,
    ),
    _ShellTab(
      scope: 'products',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Товары',
      builder: ProductsTab.new,
    ),
    _ShellTab(
      scope: 'orders',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Заказы',
      builder: OrdersTab.new,
    ),
    _ShellTab(
      scope: 'masters',
      icon: Icons.engineering_outlined,
      selectedIcon: Icons.engineering,
      label: 'Мастера',
      builder: MastersTab.new,
    ),
    _ShellTab(
      scope: 'cashier',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
      label: 'Касса',
      builder: KassaTab.new,
    ),
  ];

  List<_ShellTab> get _visibleTabs {
    final tabs = _allTabs.where((t) => widget.session.can(t.scope)).toList();
    if (widget.session.isSuperadmin) {
      tabs.add(
        const _ShellTab(
          scope: '__admins__',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: 'Админы',
          builder: AdminsTab.new,
        ),
      );
    }
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs;
    if (tabs.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'У ${widget.session.name} нет доступных разделов.\nОбратитесь к супер-админу.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      AdminAuthApi.logout();
                      widget.onLogout();
                    },
                    child: const Text('Выйти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final safeIndex = _index.clamp(0, tabs.length - 1);
    if (safeIndex != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = safeIndex);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: [for (final t in tabs) t.builder()],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (i) => setState(() => _index = i),
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final d in tabs)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
      floatingActionButton: safeIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'theme',
                  onPressed: widget.themeProvider.toggle,
                  backgroundColor: AppColors.cardElevated,
                  child: Icon(
                    widget.themeProvider.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'logout',
                  onPressed: () {
                    AdminAuthApi.logout();
                    widget.onLogout();
                  },
                  backgroundColor: AppColors.cardElevated,
                  child: const Icon(Icons.logout, color: AppColors.textSecondary),
                ),
              ],
            )
          : null,
    );
  }
}

class AdminAppBarActions extends StatelessWidget {
  const AdminAppBarActions({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Выход',
      onPressed: onLogout,
    );
  }
}
