import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';
import '../models/master.dart';
import '../utils/app_page_route.dart';
import '../screens/master_detail_screen.dart';
import '../widgets/app_cached_image.dart';

/// Карточка мастера на главном экране (фото + имя + специализация + цена).
class HomeMasterCard extends StatelessWidget {
  const HomeMasterCard({super.key, required this.master});

  final Master master;

  String get _heroImage {
    if (master.image.isNotEmpty) return master.image;
    if (master.workExamples.isNotEmpty) return master.workExamples.first;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tags = master.categoriesList.isNotEmpty
        ? master.categoriesList
        : (master.category.isNotEmpty ? [master.category] : <String>[]);
    final priceText = master.priceFrom != null &&
            master.priceFrom!.isNotEmpty &&
            master.priceFrom != 'null'
        ? 'от ${master.priceFrom} смн'
        : null;

    return RepaintBoundary(
      child: Material(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              AppPageRoute.deferred((_) => MasterDetailScreen(master: master)),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _heroImage.isNotEmpty
                    ? AppCachedImage(
                        imagePath: _heroImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        memCacheWidth: 600,
                        maxMemCacheSide: 800,
                        fallbackIcon: Icons.handyman_outlined,
                      )
                    : Container(
                        color: isDark
                            ? AppColors.inputBg
                            : AppColors.inputBgLight,
                        child: Icon(
                          Icons.handyman_outlined,
                          size: 48,
                          color: AppColors.secondary(isDark),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      master.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText(isDark),
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (priceText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        priceText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
