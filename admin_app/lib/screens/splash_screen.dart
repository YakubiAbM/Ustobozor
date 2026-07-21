import 'package:flutter/material.dart';

import '../constants.dart';
import '../widgets/admin_brand_logo.dart';

class AdminSplashScreen extends StatefulWidget {
  const AdminSplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            kSplashAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  AdminBrandLogo(size: 88, subtitle: 'Admin'),
                  SizedBox(height: 28),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
