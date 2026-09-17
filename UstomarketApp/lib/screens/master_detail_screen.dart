import 'package:flutter/material.dart';

import '../constants.dart';
import '../features/service_requests/models/service_order.dart';
import '../features/service_requests/services/service_catalog_api.dart';
import '../models/master.dart';
import '../repositories/master_repository.dart';
import '../utils/phone_launcher.dart';
import '../widgets/app_cached_image.dart';
import 'full_screen_gallery_screen.dart';

/// Единая публичная карточка мастера (главное меню и «Мои заказы»).
/// Всегда подтягивает полный профиль по id: фото, прайс, отзывы.
class MasterDetailScreen extends StatefulWidget {
  const MasterDetailScreen({super.key, required this.master});

  final Master master;

  @override
  State<MasterDetailScreen> createState() => _MasterDetailScreenState();
}

class _MasterDetailScreenState extends State<MasterDetailScreen> {
  late Master _master;
  List<MasterReview> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _master = widget.master;
    _loadFullProfile();
  }

  Future<void> _loadFullProfile() async {
    final id = widget.master.id;
    try {
      final results = await Future.wait([
        MasterRepository.instance.getById(id),
        ServiceCatalogApi.instance.masterReviews(id),
      ]);
      if (!mounted) return;
      final full = results[0] as Master?;
      final reviews = results[1] as List<MasterReview>;
      setState(() {
        if (full != null) _master = full;
        _reviews = reviews;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _callMaster() => launchPhoneCall(context, _master.phone);

  Future<void> _openWhatsApp() => launchWhatsApp(context, _master.phone);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final master = _master;
    final tags = master.categoriesList.isNotEmpty
        ? master.categoriesList
        : (master.category.isNotEmpty ? [master.category] : <String>[]);
    final priceList = master.priceList;
    final workExamples = master.workExamples;
    final hasPriceList = priceList.isNotEmpty;
    final hasWorkExamples = workExamples.isNotEmpty;

    final surfaceColor = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    final ratingCount = _reviews.isNotEmpty
        ? _reviews.length
        : master.reviewsCount;
    final ratingValue = _reviews.isNotEmpty
        ? _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            _reviews.length
        : master.rating;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFullProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.of(context).padding.top + 8,
                        16,
                        8,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: CircleAvatar(
                              backgroundColor: surfaceColor,
                              radius: 22,
                              child: Icon(
                                Icons.arrow_back,
                                color: onSurface,
                                size: 24,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_loading)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: master.image.isNotEmpty
                              ? AppCachedImage(
                                  imagePath: master.image,
                                  fit: BoxFit.cover,
                                  shape: BoxShape.circle,
                                  fallbackIcon: Icons.person,
                                  backgroundColor: surfaceColor,
                                )
                              : ColoredBox(
                                  color: surfaceColor,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 56,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Center(
                        child: Text(
                          master.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (master.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          master.phone.trim(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ],
                    if (master.city.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                master.city,
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (tags.isNotEmpty)
                      Center(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        ratingCount > 0
                            ? '★ ${ratingValue.toStringAsFixed(1)} · $ratingCount отзывов'
                            : 'Пока нет отзывов',
                        style: TextStyle(
                          color: ratingCount > 0
                              ? Colors.amber.shade800
                              : onSurface.withValues(alpha: 0.6),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Опыт работы: ${master.experience ?? '—'}',
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.85),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(onSurface, 'ПРАЙС-ЛИСТ'),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: hasPriceList
                            ? Column(
                                children: [
                                  for (int i = 0; i < priceList.length; i++) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              priceList[i].name,
                                              style: TextStyle(
                                                color: onSurface,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${priceList[i].price.toInt()} смн',
                                            style: const TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (i < priceList.length - 1)
                                      Divider(height: 1, color: dividerColor),
                                  ],
                                ],
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Услуги мастера',
                                        style: TextStyle(
                                          color: onSurface,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      master.priceFrom != null &&
                                              master.priceFrom!.isNotEmpty &&
                                              master.priceFrom != 'null'
                                          ? 'от ${master.priceFrom} смн'
                                          : '—',
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(onSurface, 'ПРИМЕРЫ РАБОТ'),
                    const SizedBox(height: 10),
                    if (hasWorkExamples)
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: workExamples.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FullScreenGalleryScreen(
                                      imageUrls: workExamples,
                                      initialIndex: i,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AppCachedImage(
                                    imagePath: workExamples[i],
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.circular(12),
                                    fallbackIcon: Icons.image,
                                    backgroundColor: surfaceColor,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          _loading
                              ? 'Загрузка фото…'
                              : 'Пока нет фотографий работ',
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    if (master.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionTitle(onSurface, 'О МАСТЕРЕ'),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            master.description.trim(),
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.9),
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _sectionTitle(onSurface, 'ОТЗЫВЫ'),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : _reviews.isEmpty
                              ? Text(
                                  'Пока нет отзывов',
                                  style: TextStyle(
                                    color: onSurface.withValues(alpha: 0.6),
                                  ),
                                )
                              : Column(
                                  children: _reviews.take(20).map((r) {
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  r.clientName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '★' * r.rating.clamp(0, 5),
                                                style: TextStyle(
                                                  color: Colors.amber.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (r.comment.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(r.comment),
                                          ],
                                          if (r.photos.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              height: 64,
                                              child: ListView.separated(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount: r.photos.length,
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(width: 6),
                                                itemBuilder: (context, i) =>
                                                    ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: AppCachedImage(
                                                    imagePath: r.photos[i],
                                                    width: 64,
                                                    height: 64,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _callMaster,
                      style: AppColors.accentButtonStyle(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Позвонить',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: _openWhatsApp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onSurface,
                        side: BorderSide(
                          color: onSurface.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'WhatsApp',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _sectionTitle(Color onSurface, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: TextStyle(
          color: onSurface.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
