import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../providers/master_auth_provider.dart';
import '../providers/app_mode_provider.dart';
import '../services/push_notification_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../features/projects/pages/my_projects_page.dart';
import '../features/service_requests/pages/service_requests_feed_page.dart';
import 'brand_products_screen.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'masters_screen.dart';
import 'materials_screen.dart';
import 'profile_screen.dart';
import 'product_detail_screen.dart';
import 'publish_work_screen.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  static bool _notificationPermissionRequested = false;

  @override
  Widget build(BuildContext context) {
    if (!_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await PushNotificationService.requestPermissionWhenEnteringApp();
        if (context.mounted) {
          final masterToken = Provider.of<MasterAuthProvider>(context, listen: false).accessToken;
          if (masterToken != null && masterToken.isNotEmpty) {
            await PushNotificationService.registerTokenIfNeeded(masterToken);
          }
        }
      });
    }

    final nav = Provider.of<NavigationProvider>(context);
    final mode = Provider.of<AppModeProvider>(context);
    final master = Provider.of<MasterAuthProvider>(context);
    final masterUi = mode.isMasterMode && master.isLoggedIn;

    final screens = [
      const HomeScreen(),
      masterUi ? const ServiceRequestsFeedPage() : const MastersScreen(),
      const PublishWorkScreen(),
      masterUi ? const MyProjectsPage() : const MaterialsScreen(),
      const CartScreen(),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (nav.detailProduct != null) {
          nav.clearProductDetail();
          return;
        }
        if (nav.selectedBrand != null) {
          nav.clearBrandProducts();
          return;
        }
        if (nav.currentIndex != NavigationProvider.tabHome) {
          nav.setIndex(NavigationProvider.tabHome);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            IndexedStack(
              index: nav.currentIndex,
              children: screens,
            ),
            if (nav.detailProduct != null)
              RepaintBoundary(
                child: ProductDetailScreen(
                  key: ValueKey(nav.detailProduct!.id),
                  product: nav.detailProduct!,
                  onBack: nav.clearProductDetail,
                ),
              ),
            if (nav.selectedBrand != null && nav.detailProduct == null)
              BrandProductsScreen(
                brandName: nav.selectedBrand!,
                onBack: nav.clearBrandProducts,
              ),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: nav.currentIndex,
          onTap: (index) {
            if (nav.detailProduct != null) nav.clearProductDetail();
            if (nav.selectedBrand != null) nav.clearBrandProducts();
            nav.setIndex(index);
          },
        ),
      ),
    );
  }
}
