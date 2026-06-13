import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/services/api_service.dart';

/// Opportunity Overview Screen — full detail view of an extracted opportunity.
///
/// Receives opportunity data as a route argument [Map<String, dynamic>].
/// Shows hero header, deadline, eligibility, requirements, benefits, skills,
/// links, contact info, summary tabs, and a bottom action bar.
class OpportunityScreen extends StatefulWidget {
  const OpportunityScreen({super.key});

  @override
  State<OpportunityScreen> createState() => _OpportunityScreenState();
}

class _OpportunityScreenState extends State<OpportunityScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _data;
  bool _isBookmarked = false;
  bool _initialized = false;

  // ── Summary tab state ──────────────────────────────────────
  final ApiService _apiService = ApiService();
  int _selectedSummaryTab = 0;
  final List<String> _summaryLevels = ['short', 'medium', 'detailed'];
  final List<String> _summaryLabels = ['30-sec', '2-min', 'Detailed'];
  final Map<int, String> _summaryCache = {};
  bool _summaryLoading = false;

  // ── Scroll ─────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _data = (args is Map<String, dynamic>) ? args : {};
      _isBookmarked = _data['bookmarked'] ?? false;
      _initialized = true;
      _loadSummary(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    setState(() {
      _headerOpacity = (1.0 - (offset / 200)).clamp(0.0, 1.0);
    });
  }

  // ── Summary helpers ────────────────────────────────────────
  Future<void> _loadSummary(int tabIndex) async {
    if (_summaryCache.containsKey(tabIndex)) return;
    final id = _data['id']?.toString();
    if (id == null) return;

    setState(() => _summaryLoading = true);
    try {
      final response = await _apiService.getSummary(
        id,
        level: _summaryLevels[tabIndex],
      );
      _summaryCache[tabIndex] = response['summary'] ?? 'No summary available.';
    } catch (_) {
      _summaryCache[tabIndex] = 'Failed to load summary. Please try again.';
    }
    if (mounted) setState(() => _summaryLoading = false);
  }

  // ── Helpers ────────────────────────────────────────────────
  Map<String, dynamic> get _extraction =>
      (_data['extraction'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _confidence =>
      (_data['confidence_scores'] as Map<String, dynamic>?) ?? {};

  String _confidenceLevel(String field) {
    final score = _confidence[field];
    if (score is num) {
      if (score >= 0.8) return 'high';
      if (score >= 0.5) return 'medium';
      return 'needs_verification';
    }
    if (score is String) return score;
    return 'medium';
  }

  int? get _daysRemaining {
    final deadline = _extraction['registration_deadline'] ?? _extraction['submission_deadline'] ?? _data['deadline'] ?? _data['last_date'];
    if (deadline == null || deadline.toString().isEmpty) return null;
    try {
      final dt = DateTime.parse(deadline.toString());
      return dt.difference(DateTime.now()).inDays;
    } catch (_) {
      return null;
    }
  }

  List<String> _toStringList(dynamic val) {
    if (val is List) return val.map((e) => e.toString()).toList();
    return [];
  }

  // ── Bookmark toggle ────────────────────────────────────────
  Future<void> _toggleBookmark() async {
    setState(() => _isBookmarked = !_isBookmarked);
    HapticFeedback.mediumImpact();
    try {
      final id = _data['id']?.toString();
      if (id != null) await _apiService.toggleBookmark(id);
    } catch (_) {
      // Revert on error
      if (mounted) setState(() => _isBookmarked = !_isBookmarked);
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background glow
          _buildBackgroundEffects(),

          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(child: _buildBody()),
            ],
          ),

          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActionBar(),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  BACKGROUND EFFECTS
  // ═════════════════════════════════════════════════════════════
  Widget _buildBackgroundEffects() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Primary glow top-right
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Accent glow bottom-left
          Positioned(
            bottom: 100,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  SLIVER APP BAR
  // ═════════════════════════════════════════════════════════════
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.background.withOpacity(0.9),
      leading: _buildAppBarButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Navigator.pop(context),
      ),
      actions: [
        _buildAppBarButton(
          icon: Icons.share_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            // TODO: share
          },
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeroHeader(),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  1. HERO HEADER
  // ═════════════════════════════════════════════════════════════
  Widget _buildHeroHeader() {
    final name = _extraction['event_name'] ?? _data['event_name'] ?? _data['title'] ?? 'Opportunity';
    final organizer = _extraction['organizer'] ?? _data['organizer'] ?? _data['organization'] ?? '';
    final type = _extraction['opportunity_type'] ?? _data['opportunity_type'] ?? _data['type'] ?? 'General';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        100,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.background,
          ],
        ),
      ),
      child: Opacity(
        opacity: _headerOpacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Type badge
            _buildTypeBadge(type.toString()),
            const SizedBox(height: AppSpacing.sm),

            // Event name
            Text(
              name.toString(),
              style: Theme.of(context).textTheme.displayMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),

            // Organizer
            if (organizer.toString().isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.business_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      organizer.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (_confidence.containsKey('organizer'))
                    ConfidenceBadge(level: _confidenceLevel('organizer')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  BODY
  // ═════════════════════════════════════════════════════════════
  Widget _buildBody() {
    int animIndex = 0;

    Widget animateSection(Widget child) {
      final delay = Duration(milliseconds: 80 * animIndex);
      animIndex++;
      return child
          .animate()
          .fadeIn(duration: 500.ms, delay: delay)
          .slideY(begin: 0.06, duration: 500.ms, delay: delay, curve: Curves.easeOut);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          animateSection(_buildDeadlineSection()),
          const SizedBox(height: AppSpacing.md),
          animateSection(_buildSummaryTabsSection()),
          const SizedBox(height: AppSpacing.md),
          animateSection(_buildEligibilitySection()),
          const SizedBox(height: AppSpacing.md),
          animateSection(_buildRequirementsSection()),
          const SizedBox(height: AppSpacing.md),
          animateSection(_buildBenefitsSection()),
          const SizedBox(height: AppSpacing.md),
          animateSection(_buildSkillsSection()),
          const SizedBox(height: AppSpacing.md),
          animateSection(_buildLinksSection()),
          const SizedBox(height: AppSpacing.md),
          animateSection(_buildContactSection()),
          // Bottom padding for action bar
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  2. DEADLINE SECTION
  // ═════════════════════════════════════════════════════════════
  Widget _buildDeadlineSection() {
    final deadline = _extraction['registration_deadline'] ?? _extraction['submission_deadline'] ?? _data['deadline'] ?? _data['last_date'];
    if (deadline == null) return const SizedBox.shrink();

    final days = _daysRemaining;
    final isUrgent = days != null && days <= 7;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (isUrgent ? AppColors.error : AppColors.warning)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isUrgent ? Icons.alarm_rounded : Icons.calendar_today_rounded,
              color: isUrgent ? AppColors.error : AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deadline',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  deadline.toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          DeadlineChip(
            deadline: deadline.toString(),
            daysRemaining: days,
            isUrgent: isUrgent,
          ),
          if (_confidence.containsKey('deadline')) ...[
            const SizedBox(width: AppSpacing.sm),
            ConfidenceBadge(level: _confidenceLevel('deadline')),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  10. SUMMARY TABS  (30-sec / 2-min / Detailed)
  // ═════════════════════════════════════════════════════════════
  Widget _buildSummaryTabsSection() {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('AI Summary',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Tab bar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: List.generate(_summaryLabels.length, (i) {
                final selected = _selectedSummaryTab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedSummaryTab = i);
                      _loadSummary(i);
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        gradient: selected ? AppColors.primaryGradient : null,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _summaryLabels[i],
                        style: TextStyle(
                          color: selected
                              ? AppColors.textOnPrimary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Summary content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _summaryLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                  )
                : Text(
                    _summaryCache[_selectedSummaryTab] ??
                        'Tap a tab to load summary.',
                    key: ValueKey(_selectedSummaryTab),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: AppColors.textPrimary.withOpacity(0.85),
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  3. ELIGIBILITY SECTION
  // ═════════════════════════════════════════════════════════════
  Widget _buildEligibilitySection() {
    final eligibility = _extraction['eligibility'] ?? _data['eligibility'];
    if (eligibility == null || eligibility.toString().isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Eligibility',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              _buildEligibilityCheckButton(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  eligibility.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: AppColors.textPrimary.withOpacity(0.9),
                      ),
                ),
              ),
              if (_confidence.containsKey('eligibility')) ...[
                const SizedBox(width: AppSpacing.sm),
                ConfidenceBadge(level: _confidenceLevel('eligibility')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityCheckButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showEligibilityBottomSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 14, color: AppColors.textOnPrimary),
            SizedBox(width: 4),
            Text(
              'Check My Eligibility',
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEligibilityBottomSheet(BuildContext context) {
    final ageController = TextEditingController();
    final gradeController = TextEditingController();
    final collegeController = TextEditingController();
    final List<String> selectedSkills = [];
    final List<String> availableSkills = [
      'Python', 'JavaScript', 'Flutter', 'React', 'Machine Learning',
      'UI/UX Design', 'Cloud Computing', 'Cybersecurity', 'Public Speaking'
    ];

    bool isLoading = false;
    Map<String, dynamic>? eligibilityResult;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.9),
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textTertiary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Eligibility Verification',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (eligibilityResult == null) ...[
                          TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Your Age',
                              labelStyle: TextStyle(color: AppColors.textTertiary),
                              prefixIcon: Icon(Icons.cake_rounded, size: 18, color: AppColors.textTertiary),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: gradeController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Your Grade / Year (e.g. 3rd Year College, Grade 12)',
                              labelStyle: TextStyle(color: AppColors.textTertiary),
                              prefixIcon: Icon(Icons.school_rounded, size: 18, color: AppColors.textTertiary),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: collegeController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Your College / School',
                              labelStyle: TextStyle(color: AppColors.textTertiary),
                              prefixIcon: Icon(Icons.apartment_rounded, size: 18, color: AppColors.textTertiary),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Your Skills',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: availableSkills.map((skill) {
                              final isSelected = selectedSkills.contains(skill);
                              return FilterChip(
                                label: Text(
                                  skill,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      selectedSkills.add(skill);
                                    } else {
                                      selectedSkills.remove(skill);
                                    }
                                  });
                                },
                                backgroundColor: AppColors.surfaceLight,
                                selectedColor: AppColors.primary,
                                checkmarkColor: AppColors.textOnPrimary,
                                side: BorderSide(
                                  color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              text: isLoading ? 'Checking Eligibility...' : 'Verify Eligibility',
                              icon: Icons.check_circle_outline_rounded,
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      setState(() => isLoading = true);
                                      try {
                                        final result = await _apiService.checkEligibility(
                                          opportunityId: _data['id'].toString(),
                                          age: int.tryParse(ageController.text),
                                          grade: gradeController.text.isEmpty ? null : gradeController.text,
                                          college: collegeController.text.isEmpty ? null : collegeController.text,
                                          skills: selectedSkills,
                                        );
                                        setState(() {
                                          eligibilityResult = result;
                                          isLoading = false;
                                        });
                                      } catch (e) {
                                        setState(() => isLoading = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: ${e.toString()}'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ),
                        ] else ...[
                          _buildEligibilityResultView(
                            eligibilityResult!,
                            onReset: () {
                              setState(() {
                                eligibilityResult = null;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEligibilityResultView(
    Map<String, dynamic> result, {
    required VoidCallback onReset,
  }) {
    final status = result['status']?.toString() ?? 'possibly_eligible';
    final reasoning = result['reasoning']?.toString() ?? '';
    final matching = _toStringList(result['matching_criteria'] ?? []);
    final missing = _toStringList(result['missing_criteria'] ?? []);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'eligible') {
      statusColor = AppColors.accent;
      statusText = 'ELIGIBLE';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'not_eligible') {
      statusColor = AppColors.error;
      statusText = 'NOT ELIGIBLE';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = AppColors.warning;
      statusText = 'POSSIBLY ELIGIBLE';
      statusIcon = Icons.help_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Reasoning',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          reasoning,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: AppColors.textPrimary.withOpacity(0.85),
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (matching.isNotEmpty) ...[
          Text(
            'Matching Criteria',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...matching.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, color: AppColors.accent, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(m, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.md),
        ],
        if (missing.isNotEmpty) ...[
          Text(
            'Missing / Verification Needed',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...missing.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(m, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.surfaceBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('Check Another Profile', style: TextStyle(color: AppColors.textPrimary)),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  4. REQUIREMENTS SECTION
  // ═════════════════════════════════════════════════════════════
  Widget _buildRequirementsSection() {
    final requirements = _toStringList(
        _extraction['requirements'] ?? _data['requirements'] ?? _data['documents_required'] ?? []);
    if (requirements.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded,
                  color: AppColors.info, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Requirements',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_confidence.containsKey('requirements'))
                ConfidenceBadge(level: _confidenceLevel('requirements')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...requirements.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: AppColors.accent),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary.withOpacity(0.9),
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  5. BENEFITS / PRIZES SECTION
  // ═════════════════════════════════════════════════════════════
  Widget _buildBenefitsSection() {
    final benefits = _toStringList(
        _extraction['benefits'] ?? _data['benefits'] ?? _data['prizes'] ?? _data['rewards'] ?? []);
    if (benefits.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Benefits & Prizes',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_confidence.containsKey('benefits'))
                ConfidenceBadge(level: _confidenceLevel('benefits')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          size: 12, color: AppColors.textOnPrimary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        b,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color:
                                      AppColors.textPrimary.withOpacity(0.9),
                                ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  6. SKILLS CHIPS
  // ═════════════════════════════════════════════════════════════
  Widget _buildSkillsSection() {
    final skills = _toStringList(
        _extraction['skills_needed'] ?? _data['skills_needed'] ?? _data['skills'] ?? []);
    if (skills.isEmpty) return const SizedBox.shrink();

    // Cycle through a few vibrant colors
    final chipColors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.info,
      AppColors.warning,
      const Color(0xFFCB7AFF), // purple
      const Color(0xFFFF6B8A), // pink
    ];

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded,
                  color: AppColors.info, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Skills Needed',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_confidence.containsKey('skills_needed'))
                ConfidenceBadge(level: _confidenceLevel('skills_needed')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: skills.asMap().entries.map((entry) {
              final color = chipColors[entry.key % chipColors.length];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  7. IMPORTANT LINKS
  // ═════════════════════════════════════════════════════════════
  Widget _buildLinksSection() {
    final links = (_extraction['important_links'] ?? _data['important_links'] ?? _data['links']);
    if (links == null) return const SizedBox.shrink();

    // links can be a List<Map> or a Map<String,String>
    List<MapEntry<String, String>> linkEntries = [];
    if (links is Map) {
      linkEntries = links.entries
          .map((e) => MapEntry(e.key.toString(), e.value.toString()))
          .toList();
    } else if (links is List) {
      for (final l in links) {
        if (l is Map) {
          linkEntries.add(MapEntry(
            (l['label'] ?? l['title'] ?? 'Link').toString(),
            (l['url'] ?? l['link'] ?? '').toString(),
          ));
        } else {
          linkEntries.add(MapEntry('Link', l.toString()));
        }
      }
    }
    if (linkEntries.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded,
                  color: AppColors.info, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Important Links',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...linkEntries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: GlassCard(
                  opacity: 0.04,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  onTap: () {
                    // TODO: launch URL
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.open_in_new_rounded,
                            size: 14, color: AppColors.info),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatFieldName(entry.key),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              entry.value,
                              style: TextStyle(
                                color: AppColors.info.withOpacity(0.8),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  8. CONTACT INFO
  // ═════════════════════════════════════════════════════════════
  Widget _buildContactSection() {
    final contactVal = _extraction['contact_info'] ?? _data['contact_info'] ?? _data['contact'];
    if (contactVal == null || contactVal.toString().isEmpty) return const SizedBox.shrink();

    final iconMap = <String, IconData>{
      'email': Icons.email_rounded,
      'phone': Icons.phone_rounded,
      'website': Icons.language_rounded,
      'address': Icons.location_on_rounded,
      'person': Icons.person_rounded,
      'name': Icons.person_rounded,
    };

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contact_mail_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('Contact Info',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_confidence.containsKey('contact_info') || _confidence.containsKey('contact'))
                ConfidenceBadge(level: _confidenceLevel(_confidence.containsKey('contact_info') ? 'contact_info' : 'contact')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (contactVal is Map)
            ...contactVal.entries.map((e) {
              final icon = iconMap.entries
                      .firstWhere(
                        (m) => e.key.toLowerCase().contains(m.key),
                        orElse: () => const MapEntry('', Icons.info_outline),
                      )
                      .value;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatFieldName(e.key),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            e.value.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList()
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    contactVal.toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: AppColors.textPrimary.withOpacity(0.9),
                        ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  9. BOTTOM ACTION BAR
  // ═════════════════════════════════════════════════════════════
  Widget _buildBottomActionBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.85),
            border: Border(
              top: BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
          child: Row(
            children: [
              // Bookmark toggle
              _buildBookmarkButton(),
              const SizedBox(width: AppSpacing.md),

              // Chat with Mentor
              Expanded(
                child: GradientButton(
                  text: 'Chat with Mentor',
                  icon: Icons.smart_toy_rounded,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/chat',
                      arguments: {
                        'opportunityId': _data['id'],
                        'opportunityName': _extraction['event_name'] ?? 'AI Mentor',
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Study Roadmap
              Expanded(
                child: GradientButton(
                  text: 'Roadmap',
                  icon: Icons.route_rounded,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/roadmap',
                      arguments: {
                        'opportunity_id': _data['id'],
                        'event_name': _extraction['event_name'] ?? 'Opportunity',
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 400.ms)
        .slideY(begin: 0.3, duration: 500.ms, delay: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildBookmarkButton() {
    return GestureDetector(
      onTap: _toggleBookmark,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _isBookmarked
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _isBookmarked
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.surfaceBorder,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            _isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            key: ValueKey(_isBookmarked),
            color: _isBookmarked ? AppColors.primary : AppColors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  UTILS
  // ═════════════════════════════════════════════════════════════
  String _formatFieldName(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : '')
        .join(' ');
  }
}
