import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/services/api_service.dart';

/// Roadmap screen showing day-by-day preparation plan.
class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final ApiService _api = ApiService();
  int _selectedDuration = 7;
  bool _isLoading = false;
  List<Map<String, dynamic>> _tasks = [];
  String _opportunityName = '';
  double _totalHours = 0;

  String? _opportunityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _opportunityId = args['opportunity_id'] as String?;
        _opportunityName = args['event_name'] as String? ?? 'Opportunity';
        _generateRoadmap();
      }
    });
  }

  Future<void> _generateRoadmap() async {
    if (_opportunityId == null) return;
    setState(() => _isLoading = true);

    try {
      final result = await _api.generateRoadmap(
        opportunityId: _opportunityId!,
        durationDays: _selectedDuration,
      );

      setState(() {
        _tasks = List<Map<String, dynamic>>.from(result['tasks'] ?? []);
        _totalHours = (result['total_estimated_hours'] ?? 0).toDouble();
        _opportunityName = result['opportunity_name'] ?? _opportunityName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate roadmap: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Preparation Roadmap'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          // ── Duration Selector ─────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _opportunityName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [3, 7, 14].map((days) {
                    final isSelected = days == _selectedDuration;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedDuration = days);
                            _generateRoadmap();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surfaceBorder,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$days',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.textOnPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Days',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? AppColors.textOnPrimary
                                            .withOpacity(0.8)
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_totalHours > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      '⏱ Total estimated: ${_totalHours.toStringAsFixed(1)} hours',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Tasks List ────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                : _tasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          return _buildTaskCard(_tasks[index], index);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, int index) {
    final day = task['day'] ?? 1;
    final title = task['title'] ?? '';
    final description = task['description'] ?? '';
    final category = task['category'] ?? 'research';
    final hours = (task['estimated_hours'] ?? 1).toDouble();
    final completed = task['completed'] ?? false;

    Color categoryColor;
    IconData categoryIcon;
    switch (category) {
      case 'skill_building':
        categoryColor = AppColors.primary;
        categoryIcon = Icons.build_rounded;
        break;
      case 'practice':
        categoryColor = AppColors.accent;
        categoryIcon = Icons.fitness_center_rounded;
        break;
      case 'logistics':
        categoryColor = AppColors.info;
        categoryIcon = Icons.checklist_rounded;
        break;
      case 'networking':
        categoryColor = const Color(0xFFFF6BFF);
        categoryIcon = Icons.people_rounded;
        break;
      default:
        categoryColor = AppColors.warning;
        categoryIcon = Icons.search_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: completed
              ? AppColors.accent.withOpacity(0.3)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                'D$day',
                style: TextStyle(
                  color: categoryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: completed
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    decoration:
                        completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(categoryIcon, size: 12, color: categoryColor),
                    const SizedBox(width: 4),
                    Text(
                      category.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 10,
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${hours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _tasks[_tasks.indexOf(task)]['completed'] = !completed;
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed
                    ? AppColors.accent
                    : Colors.transparent,
                border: Border.all(
                  color: completed
                      ? AppColors.accent
                      : AppColors.surfaceBorder,
                  width: 2,
                ),
              ),
              child: completed
                  ? const Icon(Icons.check, size: 14, color: AppColors.textOnPrimary)
                  : null,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.05);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_rounded, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No roadmap generated yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
