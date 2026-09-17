import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants.dart';
import '../../../providers/settings_provider.dart';
import '../models/project_model.dart';
import '../services/project_storage_service.dart';
import '../widgets/income_stats.dart';
import '../widgets/project_card.dart';
import 'add_project_page.dart';
import 'debtors_list_page.dart';
import 'project_details_page.dart';

class MyProjectsPage extends StatefulWidget {
  const MyProjectsPage({super.key});

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  List<ProjectModel> _projects = [];
  bool _loading = true;
  /// null = all, false = in progress, true = completed
  bool? _completedFilter;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await ProjectStorageService.instance.getAllProjects();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  List<ProjectModel> get _filtered {
    if (_completedFilter == null) return _projects;
    return _projects
        .where((p) => p.isCompleted == _completedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    final now = DateTime.now();
    final monthProjects = _projects
        .where(
          (project) =>
              project.date.year == now.year && project.date.month == now.month,
        )
        .toList();
    final monthIncome = monthProjects.fold<double>(
      0,
      (sum, project) => sum + project.income,
    );

    final debtProjects = _projects.where((p) => p.hasDebt).toList();
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('my_projects')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddProjectPage,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : RefreshIndicator(
              onRefresh: _loadProjects,
              color: AppColors.accent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    IncomeStats(
                      monthIncome: monthIncome,
                      projectCount: monthProjects.length,
                    ),
                    if (debtProjects.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DebtsBanner(
                        debtCount: debtProjects.length,
                        onTap: () => _openDebtorsList(debtProjects),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: settings.t('project_filter_all'),
                            selected: _completedFilter == null,
                            onTap: () =>
                                setState(() => _completedFilter = null),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: settings.t('project_filter_active'),
                            selected: _completedFilter == false,
                            onTap: () =>
                                setState(() => _completedFilter = false),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: settings.t('project_filter_done'),
                            selected: _completedFilter == true,
                            onTap: () =>
                                setState(() => _completedFilter = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filtered.isEmpty
                          ? _emptyState(settings)
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final project = filtered[index];
                                return ProjectCard(
                                  project: project,
                                  onTap: () => _openProjectDetails(project),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _emptyState(SettingsProvider settings) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.work_outline,
          size: 68,
          color: onSurface.withValues(alpha: 0.55),
        ),
        const SizedBox(height: 16),
        Text(
          settings.t('projects_empty_title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          settings.t('projects_empty_desc'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: _openAddProjectPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentContrastText,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            child: Text(settings.t('projects_add_btn')),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddProjectPage() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddProjectPage()),
    );

    if (saved == true) {
      await _loadProjects();
    }
  }

  Future<void> _openProjectDetails(ProjectModel project) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(projectId: project.id),
      ),
    );
    await _loadProjects();
  }

  Future<void> _openDebtorsList(List<ProjectModel> debtProjects) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DebtorsListPage(debtProjects: debtProjects),
      ),
    );

    if (updated == true) {
      await _loadProjects();
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.accent : null,
      ),
    );
  }
}

class _DebtsBanner extends StatelessWidget {
  const _DebtsBanner({
    required this.debtCount,
    required this.onTap,
  });

  final int debtCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Material(
      color: AppColors.orange.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule_outlined,
                  color: AppColors.orange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${settings.t('debts_banner')} ($debtCount)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      settings.t('debts_list_title'),
                      style: TextStyle(
                        fontSize: 13,
                        color: onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
