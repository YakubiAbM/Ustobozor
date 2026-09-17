import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/master.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../repositories/master_repository.dart';
import '../widgets/master_card.dart';

class MastersScreen extends StatefulWidget {
  const MastersScreen({super.key});

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen> {
  List<Master> _masters = [];
  bool _isLoading = true;
  bool _showList = false;
  bool _fetchStarted = false;
  String? _selectedCategory; // null = все мастера
  String? _selectedCity; // null = все города
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _defaultCategories = [
    'Алюкобонд',
    'Евроремонт',
    'Маляр',
    'Плиточник',
    'Разнорабочий',
    'Сантехник',
    'Сварщик',
    'Электрик',
  ];

  List<String> get _cities {
    final set = <String>{};
    for (final m in _masters) {
      final c = m.city.trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  bool _cityMatch(Master m, String? city) {
    if (city == null || city.isEmpty) return true;
    final a = m.city.toLowerCase().replaceFirst(RegExp(r'^г\.\s*'), '').trim();
    final b = city.toLowerCase().replaceFirst(RegExp(r'^г\.\s*'), '').trim();
    return a == b || a.contains(b) || b.contains(a);
  }

  @override
  void initState() {
    super.initState();
    _loadCachedMasters();
    _searchController.addListener(
      () => setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Provider.of<NavigationProvider>(context, listen: false);
      nav.addListener(_onNavChanged);
      if (nav.currentIndex == NavigationProvider.tabMasters) _ensureFetch();
    });
  }

  void _onNavChanged() {
    if (!mounted) return;
    final nav = Provider.of<NavigationProvider>(context, listen: false);
    if (nav.currentIndex == NavigationProvider.tabMasters) _ensureFetch();
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
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Ошибка загрузки мастеров: $e');
    }
  }

  List<String> get _categories {
    final Set<String> set = {};
    for (final m in _masters) {
      if (m.categoriesList.isNotEmpty) {
        set.addAll(m.categoriesList);
      } else if (m.category.isNotEmpty) {
        set.add(m.category);
      }
    }
    final list = set.toList()..sort();
    if (list.isEmpty) return _defaultCategories;
    return list;
  }

  List<Master> get _filteredMasters {
    List<Master> list = _masters;
    if (_selectedCategory != null) {
      list = list.where((m) {
        if (m.categoriesList.isNotEmpty)
          return m.categoriesList.contains(_selectedCategory);
        return m.category == _selectedCategory;
      }).toList();
    }
    if (_selectedCity != null) {
      list = list.where((m) => _cityMatch(m, _selectedCity)).toList();
    }
    if (_searchQuery.isEmpty) return list;
    return list.where((m) {
      if (m.name.toLowerCase().contains(_searchQuery)) return true;
      for (final c in m.categoriesList) {
        if (c.toLowerCase().contains(_searchQuery)) return true;
      }
      if (m.category.toLowerCase().contains(_searchQuery)) return true;
      if (m.city.toLowerCase().contains(_searchQuery)) return true;
      return false;
    }).toList();
  }

  String get _listTitle {
    if (_selectedCategory == null) return 'ВСЕ МАСТЕРА';
    return _selectedCategory!.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    if (_showList) {
      final filtered = _filteredMasters;
      return Scaffold(
        backgroundColor: theme.brightness == Brightness.dark
            ? AppColors.bg
            : AppColors.bgLight,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ustobozor
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
                child: Text(
                  'Ustomarket',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // Поиск
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск мастера (имя, профессия, город)...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      size: 22,
                    ),
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark
                        ? AppColors.inputBg
                        : AppColors.inputBgLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_cities.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Все города'),
                          selected: _selectedCity == null,
                          onSelected: (_) => setState(() => _selectedCity = null),
                          selectedColor: AppColors.accent.withOpacity(0.25),
                          checkmarkColor: AppColors.accent,
                        ),
                      ),
                      ..._cities.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(c),
                            selected: _selectedCity == c,
                            onSelected: (_) => setState(() => _selectedCity = c),
                            selectedColor: AppColors.accent.withOpacity(0.25),
                            checkmarkColor: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // ← ВСЕ МАСТЕРА (N)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 15, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => setState(() => _showList = false),
                    ),
                    Expanded(
                      child: Text(
                        '${_listTitle} (${filtered.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      )
                    : filtered.isEmpty
                    ? Center(
                        child: Text(
                          settings.t('empty_masters'),
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) =>
                            MasterCard(master: filtered[i]),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.bg
          : AppColors.bgLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 6),
              child: Text(
                'Ustomarket',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                settings.t('categories_services'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    )
                  : GridView.count(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 80),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.8,
                      children: [
                        _CategoryChip(
                          label: settings.t('all_masters_upper'),
                          selected: true,
                          onTap: () {
                            setState(() {
                              _selectedCategory = null;
                              _showList = true;
                            });
                          },
                          theme: theme,
                        ),
                        ..._categories.map(
                          (cat) => _CategoryChip(
                            label: cat.toUpperCase(),
                            selected: false,
                            onTap: () {
                              setState(() {
                                _selectedCategory = cat;
                                _showList = true;
                              });
                            },
                            theme: theme,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accent : Colors.grey.withOpacity(0.3),
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? AppColors.accent : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
