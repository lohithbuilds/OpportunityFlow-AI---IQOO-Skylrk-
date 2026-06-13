import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

/// Profile screen for student details, skills, and interests.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController(text: 'Student');
  final _ageController = TextEditingController();
  final _gradeController = TextEditingController();
  final _collegeController = TextEditingController();

  final List<String> _selectedSkills = [];
  final List<String> _selectedInterests = [];

  final List<String> _availableSkills = [
    'Python', 'JavaScript', 'Flutter', 'React', 'Machine Learning',
    'Data Science', 'UI/UX Design', 'Cloud Computing', 'Cybersecurity',
    'Blockchain', 'IoT', 'Mobile Development', 'Web Development',
    'Public Speaking', 'Leadership', 'Project Management',
  ];

  final List<String> _availableInterests = [
    'Hackathons', 'Scholarships', 'Internships', 'Olympiads',
    'Research', 'Startups', 'Open Source', 'Competitive Programming',
    'Sports', 'Cultural Events', 'Fellowships', 'Workshops',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _gradeController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar ──────────────────────────────────
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

            const SizedBox(height: AppSpacing.lg),

            // ── Personal Info ───────────────────────────
            _buildSection(
              'Personal Details',
              Icons.person_outline_rounded,
              Column(
                children: [
                  _buildTextField('Full Name', _nameController, Icons.badge_rounded),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Age', _ageController, Icons.cake_rounded,
                            keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _buildTextField('Grade/Year', _gradeController, Icons.school_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildTextField('College/Institution', _collegeController, Icons.apartment_rounded),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Skills ──────────────────────────────────
            _buildSection(
              'Skills',
              Icons.code_rounded,
              _buildChipSelector(_availableSkills, _selectedSkills, AppColors.primary),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Interests ───────────────────────────────
            _buildSection(
              'Interests',
              Icons.interests_rounded,
              _buildChipSelector(_availableInterests, _selectedInterests, AppColors.accent),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Save Button ─────────────────────────────
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'Save Profile',
                icon: Icons.save_rounded,
                onPressed: _saveProfile,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          content,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _buildChipSelector(
    List<String> options,
    List<String> selected,
    Color color,
  ) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(
            option,
            style: TextStyle(
              color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                selected.add(option);
              } else {
                selected.remove(option);
              }
            });
          },
          backgroundColor: AppColors.surfaceLight,
          selectedColor: color,
          checkmarkColor: AppColors.textOnPrimary,
          side: BorderSide(
            color: isSelected ? color : AppColors.surfaceBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }).toList(),
    );
  }

  void _saveProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile saved successfully!'),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
