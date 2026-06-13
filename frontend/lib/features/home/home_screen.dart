import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

/// Home dashboard with upload CTA, recent opportunities, and deadlines.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Mock data — will be replaced with API calls
  final List<Map<String, dynamic>> recentOpportunities = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back 👋',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'OpportunityFlow',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                  ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                  ],
                ),
              ),
            ),

            // ── Upload CTA Card ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: _buildUploadCard(context),
              ),
            ),

            // ── Deadline Alerts ─────────────────────────
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '🔴 Upcoming Deadlines',
                subtitle: 'Don\'t miss out!',
              ),
            ),

            SliverToBoxAdapter(
              child: _buildDeadlineSection(),
            ),

            // ── Recent Opportunities ────────────────────
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '📋 Recent Opportunities',
                subtitle: 'Your analyzed documents',
                onSeeAll: () {},
              ),
            ),

            SliverToBoxAdapter(
              child: _buildRecentSection(),
            ),

            // ── Quick Stats ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _buildStatsRow(),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),

      // ── Floating Upload Button ────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/upload'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Scan Opportunity',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildUploadCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/upload'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A00), Color(0xFF0D1A00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload & Analyze',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Drop a PDF, poster, or screenshot and let AI extract all the details',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'PDF · Image · Link',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 32,
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildDeadlineSection() {
    // Placeholder — will show real deadlines from the API
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No deadlines yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload an opportunity to track deadlines',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 400.ms),
    );
  }

  Widget _buildRecentSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No opportunities analyzed yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your analyzed opportunities will appear here',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 600.ms),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Total', '0', Icons.analytics_rounded, AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        _buildStatCard('Applied', '0', Icons.send_rounded, AppColors.info),
        const SizedBox(width: AppSpacing.sm),
        _buildStatCard('Saved', '0', Icons.bookmark_rounded, AppColors.accent),
      ],
    ).animate().fadeIn(delay: 800.ms);
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.sm),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
