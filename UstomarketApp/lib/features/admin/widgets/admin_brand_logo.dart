import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

class AdminBrandLogo extends StatelessWidget {
  const AdminBrandLogo({
    super.key,
    this.size = 72,
    this.showSubtitle = true,
    this.subtitle = 'Admin',
  });

  final double size;
  final bool showSubtitle;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            kAppIconAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              color: AppColors.card,
              child: Icon(Icons.storefront_rounded, size: size * 0.5, color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ustomarket',
          style: GoogleFonts.montserrat(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
            letterSpacing: 0.5,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
