import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models/master.dart';
import '../providers/settings_provider.dart';
import '../screens/full_screen_gallery_screen.dart';
import '../screens/master_detail_screen.dart';
import '../utils/app_page_route.dart';
import '../utils/phone_launcher.dart';
import 'app_cached_image.dart';

/// Карточка мастера на главном экране (как в макете: аватар, прайс, галерея, контакт).
class HomeMasterCard extends StatelessWidget {
  const HomeMasterCard({super.key, required this.master});

  final Master master;

  static IconData _categoryIcon(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('ванн') || t.contains('сантех') || t.contains('кафел')) {
      return Icons.bathtub_outlined;
    }
    if (t.contains('маляр') || t.contains('штукат') || t.contains('покраск')) {
      return Icons.format_paint_outlined;
    }
    if (t.contains('электр')) return Icons.electrical_services_outlined;
    if (t.contains('плот') || t.contains('мебел') || t.contains('дерев')) {
      return Icons.carpenter_outlined;
    }
    if (t.contains('кровл') || t.contains('крыш')) return Icons.roofing_outlined;
    if (t.contains('бетон') || t.contains('кладк') || t.contains('камен')) {
      return Icons.foundation_outlined;
    }
    return Icons.handyman_outlined;
  }

  String _formatPrice(num price) {
    final n = price.round();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _reviewsWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'отзыв';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'отзыва';
    }
    return 'отзывов';
  }

  bool get _isUrgent {
    final blob =
        '${master.description} ${master.category}'.toLowerCase();
    return blob.contains('сроч') ||
        blob.contains('срочный') ||
        blob.contains('фавр') ||
        blob.contains('24/7') ||
        blob.contains('24ч');
  }

  bool get _is247 {
    final blob =
        '${master.description} ${master.category}'.toLowerCase();
    return blob.contains('24/7') ||
        blob.contains('24ч') ||
        blob.contains('круглосут');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final onSurface = theme.colorScheme.onSurface;
    final tags = master.categoriesList.isNotEmpty
        ? master.categoriesList
        : (master.category.isNotEmpty ? [master.category] : <String>[]);
    final priceList = master.priceList.take(3).toList();
    final gallery = master.workExamples;

    return RepaintBoundary(
      child: Material(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              AppPageRoute.deferred((_) => MasterDetailScreen(master: master)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.55),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: master.image.isNotEmpty
                            ? AppCachedImage(
                                imagePath: master.image,
                                fit: BoxFit.cover,
                                width: 72,
                                height: 72,
                                shape: BoxShape.circle,
                                memCacheWidth: 200,
                                fallbackIcon: Icons.person,
                              )
                            : ColoredBox(
                                color: isDark
                                    ? AppColors.inputBg
                                    : AppColors.inputBgLight,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 36,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            master.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (kMasterReviewsEnabled)
                            Row(
                              children: [
                                if (master.reviewsCount > 0) ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFBBF24),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    master.rating.toStringAsFixed(
                                      master.rating ==
                                              master.rating.roundToDouble()
                                          ? 0
                                          : 1,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${master.reviewsCount} ${_reviewsWord(master.reviewsCount)})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.secondary(isDark),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    'Пока нет отзывов',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.secondary(isDark),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (master.experience != null &&
                                    master.experience! > 0) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    '${master.experience} лет',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.secondary(isDark),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else if (master.experience != null &&
                              master.experience! > 0)
                            Text(
                              'Опыт: ${master.experience} лет',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.secondary(isDark),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (master.city.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.1),
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
                          if (_is247 || _isUrgent) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (_is247)
                                  _StatusBadge(
                                    label: '24/7',
                                    color: AppColors.accent,
                                  ),
                                if (_isUrgent)
                                  _StatusBadge(
                                    label: settings.t('urgent_call'),
                                    color: const Color(0xFF7C3AED),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 16,
                                color: const Color(0xFF7C3AED).withValues(
                                  alpha: 0.9,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.payments_outlined,
                                size: 16,
                                color: const Color(0xFF7C3AED).withValues(
                                  alpha: 0.9,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.badge_outlined,
                                size: 16,
                                color: const Color(0xFF7C3AED).withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tags.length.clamp(0, 6),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final tag = tags[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.divider(isDark),
                            ),
                            color: isDark
                                ? AppColors.inputBg
                                : AppColors.bgLight,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _categoryIcon(tag),
                                size: 16,
                                color: AppColors.secondary(isDark),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (priceList.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...priceList.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: onSurface.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 6,
                                right: 6,
                                bottom: 3,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final dots =
                                      (constraints.maxWidth / 5).floor().clamp(
                                    3,
                                    40,
                                  );
                                  return Text(
                                    List.filled(dots, '·').join(),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1,
                                      color: AppColors.secondary(isDark)
                                          .withValues(alpha: 0.55),
                                      letterSpacing: 1.2,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            'от ${_formatPrice(item.price)} смн',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else if (master.priceFrom != null &&
                    master.priceFrom!.isNotEmpty &&
                    master.priceFrom != 'null') ...[
                  const SizedBox(height: 12),
                  Text(
                    'от ${master.priceFrom} смн',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ],
                if (gallery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gallery.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenGalleryScreen(
                                  imageUrls: gallery,
                                  initialIndex: i,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 110,
                              height: 88,
                              child: AppCachedImage(
                                imagePath: gallery[i],
                                fit: BoxFit.cover,
                                width: 110,
                                height: 88,
                                memCacheWidth: 320,
                                fallbackIcon: Icons.photo_outlined,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => launchPhoneCall(context, master.phone),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentContrastText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      settings.t('contact_master'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
