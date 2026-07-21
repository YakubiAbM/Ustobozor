import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models/master.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../repositories/master_repository.dart';
import '../widgets/home_master_card.dart';

/// Главное меню: приоритет — мастера (поиск + лента карточек).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Master> _masters = [];
  bool _isLoading = true;
  bool _fetchStarted = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCachedMasters();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Provider.of<NavigationProvider>(context, listen: false);
      nav.addListener(_onNavChanged);
      if (nav.currentIndex == NavigationProvider.tabHome) _ensureFetch();
    });
  }

  void _onNavChanged() {
    if (!mounted) return;
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    if (nav.currentIndex == NavigationProvider.tabHome) _ensureFetch();
    if (nav.requestHomeRefresh) {
      nav.clearRequestHomeRefresh();
      _fetchMasters();
    }
  }

  @override
  void dispose() {
    Provider.of<NavigationProvider>(context, listen: false)
        .removeListener(_onNavChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _ensureFetch() {
    if (_fetchStarted) return;
    _fetchStarted = true;
    _fetchMasters();
  }

  Future<void> _loadCachedMasters() async {
    final masters = await MasterRepository.instance.getCachedAllMasters();
    if (!mounted || masters.isEmpty) return;
    setState(() {
      _masters = masters;
      _isLoading = false;
    });
  }

  Future<void> _fetchMasters() async {
    try {
      final masters = await MasterRepository.instance.refreshAllMasters();
      if (!mounted) return;
      setState(() {
        _masters = masters;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Master> get _filteredMasters {
    if (_searchQuery.isEmpty) return _masters;
    return _masters.where((m) {
      if (m.name.toLowerCase().contains(_searchQuery)) return true;
      for (final c in m.categoriesList) {
        if (c.toLowerCase().contains(_searchQuery)) return true;
      }
      if (m.category.toLowerCase().contains(_searchQuery)) return true;
      return false;
    }).toList();
  }

  void _openMaterialsTab() {
    Provider.of<NavigationProvider>(context, listen: false)
        .setIndex(NavigationProvider.tabMaterials);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredMasters;

    return Scaffold(
      backgroundColor: AppColors.scaffold(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.screenHorizontalPadding,
                12,
                AppLayout.screenHorizontalPadding,
                0,
              ),
              child: Text(
                'Ustomarket',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: AppColors.accent,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.screenHorizontalPadding,
                14,
                AppLayout.screenHorizontalPadding,
                8,
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: settings.t('search_master_hint'),
                  hintStyle: TextStyle(
                    color: AppColors.secondary(isDark),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.secondary(isDark),
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close,
                            color: AppColors.secondary(isDark),
                            size: 20,
                          ),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.inputFill(isDark),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppLayout.cardBorderRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accent,
                onRefresh: _fetchMasters,
                child: _isLoading && _masters.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppLayout.screenHorizontalPadding,
                          8,
                          AppLayout.screenHorizontalPadding,
                          88,
                        ),
                        itemCount: filtered.isEmpty
                            ? 2
                            : filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _MaterialsBanner(
                                isDark: isDark,
                                onTap: _openMaterialsTab,
                              ),
                            );
                          }
                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: Text(
                                  settings.t('empty_masters'),
                                  style: TextStyle(
                                    color: AppColors.secondary(isDark),
                                  ),
                                ),
                              ),
                            );
                          }
                          final master = filtered[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: HomeMasterCard(master: master),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialsBanner extends StatelessWidget {
  const _MaterialsBanner({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final base = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final gradientEnd = isDark
        ? AppColors.bannerGradientEndDark
        : AppColors.bannerGradientEndLight;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppLayout.cardBorderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, base, gradientEnd],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.accent,
                radius: 28,
                child: Icon(
                  Icons.storefront_outlined,
                  color: AppColors.accentContrastText,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('materials_banner_title'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.t('materials_banner_subtitle'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  settings.t('materials'),
                  style: const TextStyle(
                    color: AppColors.accentContrastText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
