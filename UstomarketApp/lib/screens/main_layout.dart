import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/cart_provider.dart';
import '../providers/master_auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../services/push_notification_service.dart';
import 'brand_products_screen.dart';
import 'cart_screen.dart';
import 'catalog_screen.dart';
import 'home_screen.dart';
import 'masters_screen.dart';
import 'profile_screen.dart';
import 'product_detail_screen.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  static bool _notificationPermissionRequested = false;

  @override
  Widget build(BuildContext context) {
    // Один раз при входе в приложение запрашиваем разрешение на уведомления
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

    final settings = Provider.of<SettingsProvider>(context);
    final nav = Provider.of<NavigationProvider>(context);
    final screens = [
      const HomeScreen(),
      const MastersScreen(),
      const CatalogScreen(),
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
        if (nav.currentIndex != 0) {
          nav.setIndex(0);
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
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider(settings.isDarkMode), width: 0.5)),
          ),
          child: BottomNavigationBar(
            currentIndex: nav.currentIndex,
            onTap: (index) {
            if (nav.detailProduct != null) nav.clearProductDetail();
            if (nav.selectedBrand != null) nav.clearBrandProducts();
            nav.setIndex(index);
          },
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: settings.t('home')),
              BottomNavigationBarItem(icon: const Icon(Icons.handyman_outlined), activeIcon: const Icon(Icons.handyman), label: settings.t('masters')),
              BottomNavigationBarItem(icon: const Icon(Icons.grid_view), label: settings.t('catalog')),
              BottomNavigationBarItem(
                icon: Consumer<CartProvider>(
                  builder: (ctx, cart, child) => Badge(
                    isLabelVisible: cart.itemCount > 0,
                    label: Text('${cart.itemCount}'),
                    backgroundColor: AppColors.accent,
                    textColor: AppColors.accentContrastText,
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                ),
                label: settings.t('cart'),
              ),
              BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: settings.t('profile')),
            ],
          ),
        ),
      ),
    );
  }
}
