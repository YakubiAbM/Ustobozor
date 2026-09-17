import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/master.dart';
import '../utils/app_page_route.dart';
import '../utils/phone_launcher.dart';
import '../screens/master_detail_screen.dart';
import 'app_cached_image.dart';

class MasterCard extends StatelessWidget {
  final Master master;

  const MasterCard({super.key, required this.master});

  static String _reviewsWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'отзыв';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'отзыва';
    }
    return 'отзывов';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tags = master.categoriesList.isNotEmpty
        ? master.categoriesList
        : (master.category.isNotEmpty ? [master.category] : <String>[]);
    final priceText =
        master.priceFrom != null &&
            master.priceFrom!.isNotEmpty &&
            master.priceFrom != 'null'
        ? 'от ${master.priceFrom} смн'
        : 'от --- смн';

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            AppPageRoute.deferred(
              (_) => MasterDetailScreen(master: master),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider(isDark)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent, width: 2),
                  color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
                ),
                child: master.image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppCachedImage(
                          imagePath: master.image,
                          fit: BoxFit.cover,
                          width: 70,
                          height: 70,
                          memCacheWidth: 200,
                          maxMemCacheSide: 400,
                          borderRadius: BorderRadius.circular(12),
                          fallbackIcon: Icons.person,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.grey, size: 36),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      master.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (kMasterReviewsEnabled) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (master.reviewsCount > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFBBF24),
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              master.rating.toStringAsFixed(
                                master.rating == master.rating.roundToDouble()
                                    ? 0
                                    : 1,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '(${master.reviewsCount} ${_reviewsWord(master.reviewsCount)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ] else
                            Text(
                              'Пока нет отзывов',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary(isDark),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (master.city.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 13,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                master.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags
                            .take(5)
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.95),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      priceText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () => launchPhoneCall(context, master.phone),
                    icon: const CircleAvatar(
                      backgroundColor: AppColors.accent,
                      radius: 20,
                      child: Icon(
                        Icons.phone,
                        color: AppColors.accentContrastText,
                        size: 20,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    onPressed: () => launchWhatsApp(context, master.phone),
                    icon: const CircleAvatar(
                      backgroundColor: AppColors.accent,
                      radius: 20,
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.accentContrastText,
                        size: 20,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
