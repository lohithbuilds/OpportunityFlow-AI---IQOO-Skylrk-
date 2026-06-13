import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

/// Analysis screen showing real-time extraction progress.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isComplete = false;
  Map<String, dynamic>? _opportunityData;

  final List<_AnalysisStep> _steps = [
    _AnalysisStep(
      icon: Icons.upload_file_rounded,
      title: 'Uploading Document',
      subtitle: 'Securely processing your file',
    ),
    _AnalysisStep(
      icon: Icons.text_snippet_rounded,
      title: 'Parsing Content',
      subtitle: 'Extracting text and structure',
    ),
    _AnalysisStep(
      icon: Icons.auto_awesome_rounded,
      title: 'AI Extraction',
      subtitle: 'Identifying key opportunity details',
    ),
    _AnalysisStep(
      icon: Icons.verified_rounded,
      title: 'Validating Data',
      subtitle: 'Scoring confidence & checking deadlines',
    ),
    _AnalysisStep(
      icon: Icons.check_circle_rounded,
      title: 'Ready!',
      subtitle: 'Your opportunity mentor is prepared',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Get the opportunity data from route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _opportunityData = args;
        _simulateAnalysis();
      } else {
        _simulateAnalysis();
      }
    });
  }

  Future<void> _simulateAnalysis() async {
    // Simulate the processing steps with delays
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(Duration(milliseconds: i == 2 ? 1200 : 600));
      if (mounted) {
        setState(() => _currentStep = i);
      }
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),

              // ── Processing Animation ──────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isComplete
                      ? AppColors.accentGradient
                      : AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (_isComplete ? AppColors.accent : AppColors.primary)
                          .withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isComplete
                      ? Icons.check_rounded
                      : Icons.auto_awesome_rounded,
                  size: 48,
                  color: AppColors.textOnPrimary,
                ),
              ).animate(target: _isComplete ? 1 : 0).scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.1, 1.1),
                    duration: 300.ms,
                  ),

              const SizedBox(height: AppSpacing.xl),

              // ── Title ─────────────────────────────────
              Text(
                _isComplete ? 'Analysis Complete!' : 'Analyzing Document',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: _isComplete ? AppColors.accent : AppColors.primary,
                    ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Steps List ────────────────────────────
              ...List.generate(_steps.length, (index) {
                final step = _steps[index];
                final isActive = index == _currentStep;
                final isDone = index < _currentStep;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppColors.accent.withOpacity(0.15)
                              : isActive
                                  ? AppColors.primary.withOpacity(0.15)
                                  : AppColors.surface,
                          border: Border.all(
                            color: isDone
                                ? AppColors.accent
                                : isActive
                                    ? AppColors.primary
                                    : AppColors.surfaceBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : step.icon,
                          size: 16,
                          color: isDone
                              ? AppColors.accent
                              : isActive
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                color: isDone || isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                                fontSize: 14,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            Text(
                              step.subtitle,
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isActive && !_isComplete)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: 100 * index));
              }),

              const Spacer(),

              // ── Continue Button ───────────────────────
              if (_isComplete)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/opportunity',
                        arguments: _opportunityData?['data'],
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'View Opportunity Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisStep {
  final IconData icon;
  final String title;
  final String subtitle;

  _AnalysisStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
