import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../models/master.dart';
import '../widgets/app_cached_image.dart';
import 'full_screen_gallery_screen.dart';

class MasterDetailScreen extends StatelessWidget {
  final Master master;

  const MasterDetailScreen({super.key, required this.master});

  Future<void> _callMaster(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final path = clean.startsWith('992') ? clean : '992$clean';
    final uri = Uri(scheme: 'tel', path: path);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    final path = clean.startsWith('992') ? clean : '992$clean';
    final uri = Uri.parse('https://wa.me/$path');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.08);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Кнопка назад
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
                            color: AppColors.accent.withOpacity(0.2),
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
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (tags.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tags.first,
                          style: TextStyle(color: onSurface, fontSize: 14),
                        ),
                      ),
                    ),
                  if (tags.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Center(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: tags
                              .skip(1)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Опыт работы: ${master.experience ?? '—'}',
                      style: TextStyle(
                        color: onSurface.withOpacity(0.85),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'ПРАЙС-ЛИСТ',
                      style: TextStyle(
                        color: onSurface.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'ПРИМЕРЫ РАБОТ',
                      style: TextStyle(
                        color: onSurface.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (hasWorkExamples)
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: workExamples.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenGalleryScreen(
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
                      child: SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _placeholderWorkCard(context),
                            const SizedBox(width: 12),
                            _placeholderWorkCard(context),
                          ],
                        ),
                      ),
                    ),
                  if (master.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'О МАСТЕРЕ',
                        style: TextStyle(
                          color: onSurface.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
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
                            color: onSurface.withOpacity(0.9),
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
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
                      onPressed: () => _callMaster(master.phone),
                      style: AppColors.accentButtonStyle(padding: const EdgeInsets.symmetric(vertical: 14)),
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
                      onPressed: () => _openWhatsApp(master.phone),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onSurface,
                        side: BorderSide(color: onSurface.withOpacity(0.4)),
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

  Widget _placeholderWorkCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: const Center(
        child: Icon(Icons.photo_library_outlined, color: Colors.grey, size: 40),
      ),
    );
  }
}
