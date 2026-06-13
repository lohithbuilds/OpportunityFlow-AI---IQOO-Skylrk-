import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/services/api_service.dart';

/// Upload screen — lets users upload PDFs, images, or paste URLs
/// for AI-powered opportunity extraction.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _urlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _selectedFileName;
  String? _selectedFilePath;
  String _uploadStatusText = '';

  late AnimationController _pulseController;
  late AnimationController _borderController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _borderAnimation;

  // Mock recent uploads — will be replaced with local storage / API
  final List<Map<String, dynamic>> _recentUploads = [
    {
      'name': 'Google_SWE_Intern_2026.pdf',
      'type': 'pdf',
      'date': '2 hours ago',
      'status': 'analyzed',
    },
    {
      'name': 'Hackathon_Poster.png',
      'type': 'image',
      'date': '1 day ago',
      'status': 'analyzed',
    },
    {
      'name': 'https://unstop.com/hackathon/...',
      'type': 'url',
      'date': '3 days ago',
      'status': 'analyzed',
    },
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _borderController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _borderAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _borderController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _borderController.dispose();
    _urlController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  // ── Upload Handlers ─────────────────────────────────────────

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          if (!kIsWeb) {
            _selectedFilePath = file.path;
          }
        });
        if (kIsWeb) {
          if (file.bytes != null) {
            await _uploadFile(fileBytes: file.bytes, fileName: file.name);
          } else {
            _showError('No file data available');
          }
        } else {
          if (file.path != null) {
            await _uploadFile(filePath: file.path, fileName: file.name);
          }
        }
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );

      if (image != null) {
        setState(() {
          _selectedFileName = image.name;
          if (!kIsWeb) {
            _selectedFilePath = image.path;
          }
        });
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          await _uploadFile(fileBytes: bytes, fileName: image.name);
        } else {
          await _uploadFile(filePath: image.path, fileName: image.name);
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _submitURL() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter a valid URL');
      return;
    }

    if (!Uri.tryParse(url)!.hasAbsolutePath) {
      _showError('Please enter a valid URL');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusText = 'Fetching URL content...';
      _selectedFileName = url;
    });

    _simulateProgress();

    try {
      final responseData = await _apiService.uploadDocument(filePath: url, fileName: 'url_upload');

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
        _uploadStatusText = 'Analysis complete!';
      });

      if (mounted) {
        Navigator.pushNamed(context, '/analysis', arguments: responseData);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _uploadStatusText = '';
      });
      _showError('Failed to process URL: $e');
    }
  }

  Future<void> _uploadFile({
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusText = 'Preparing document...';
    });

    _simulateProgress();

    try {
      final responseData = await _apiService.uploadDocument(
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
      );

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
        _uploadStatusText = 'Analysis complete!';
      });

      if (mounted) {
        Navigator.pushNamed(context, '/analysis', arguments: responseData);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _uploadStatusText = '';
        _selectedFileName = null;
        _selectedFilePath = null;
      });
      _showError('Upload failed: $e');
    }
  }

  void _simulateProgress() async {
    final stages = [
      (0.15, 'Uploading document...'),
      (0.35, 'Processing with AI...'),
      (0.55, 'Extracting opportunity details...'),
      (0.75, 'Analyzing eligibility criteria...'),
      (0.90, 'Finalizing analysis...'),
    ];

    for (final stage in stages) {
      if (!_isUploading) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && _isUploading) {
        setState(() {
          _uploadProgress = stage.$1;
          _uploadStatusText = stage.$2;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Choose Image Source',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.info,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildSourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Document',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'PDF, image, or URL',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            'AI Powered',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
              ),
            ),

            // ── Upload Area ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: _isUploading
                    ? _buildUploadProgress()
                    : _buildUploadDropZone(),
              ),
            ),

            // ── Upload Options ─────────────────────────
            if (!_isUploading) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'CHOOSE UPLOAD METHOD',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: [
                      // PDF Option
                      _buildUploadOptionCard(
                        icon: Icons.picture_as_pdf_rounded,
                        iconColor: const Color(0xFFFF4444),
                        title: 'PDF Document',
                        subtitle:
                            'Upload scholarship notices, event brochures, or official documents',
                        formats: 'PDF, DOC, DOCX',
                        onTap: _pickPDF,
                        delay: 400,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Image Option
                      _buildUploadOptionCard(
                        icon: Icons.image_rounded,
                        iconColor: const Color(0xFF4EA8FF),
                        title: 'Image / Photo',
                        subtitle:
                            'Snap a poster, screenshot, or any image with opportunity info',
                        formats: 'JPG, PNG, HEIC',
                        onTap: _showImageSourceDialog,
                        delay: 500,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // URL Option
                      _buildURLCard(),
                    ],
                  ),
                ),
              ),
            ],

            // ── Recent Uploads ─────────────────────────
            if (!_isUploading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: SectionHeader(
                    title: '📄 Recent Uploads',
                    subtitle: 'Previously analyzed documents',
                  ),
                ).animate().fadeIn(delay: 700.ms),
              ),

            if (!_isUploading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: _buildRecentUploads(),
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upload Drop Zone ────────────────────────────────────────

  Widget _buildUploadDropZone() {
    return AnimatedBuilder(
      animation: _borderAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: CustomPaint(
            painter: _DottedBorderPainter(
              color: AppColors.primary.withOpacity(0.4),
              strokeWidth: 2.0,
              gap: 8.0,
              radius: AppRadius.xl,
              dashOffset: _borderAnimation.value * 40,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxl,
                horizontal: AppSpacing.lg,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated upload icon
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary
                                  .withOpacity(0.15 * _pulseAnimation.value),
                              AppColors.accent
                                  .withOpacity(0.08 * _pulseAnimation.value),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary
                                .withOpacity(0.2 * _pulseAnimation.value),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.cloud_upload_rounded,
                          size: 36,
                          color: AppColors.primary
                              .withOpacity(0.6 + 0.4 * _pulseAnimation.value),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Drop your document here',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'or choose an upload method below',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Format chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFormatChip('PDF', const Color(0xFFFF4444)),
                      const SizedBox(width: AppSpacing.sm),
                      _buildFormatChip('Image', const Color(0xFF4EA8FF)),
                      const SizedBox(width: AppSpacing.sm),
                      _buildFormatChip('URL', AppColors.accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 600.ms, delay: 150.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
          duration: 500.ms,
          delay: 150.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildFormatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Upload Option Card ──────────────────────────────────────

  Widget _buildUploadOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String formats,
    required VoidCallback onTap,
    required int delay,
  }) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: iconColor.withOpacity(0.15)),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formats,
                  style: TextStyle(
                    color: AppColors.textTertiary.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideX(
          begin: 0.05,
          duration: 400.ms,
          delay: Duration(milliseconds: delay),
          curve: Curves.easeOut,
        );
  }

  // ── URL Card ────────────────────────────────────────────────

  Widget _buildURLCard() {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: AppColors.accent.withOpacity(0.15)),
                ),
                child: const Icon(Icons.link_rounded,
                    color: AppColors.accent, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste URL',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paste a link from Unstop, LinkedIn, or any website',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // URL input field
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://example.com/opportunity',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary.withOpacity(0.5),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.language_rounded,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    onSubmitted: (_) => _submitURL(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: _submitURL,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: AppColors.textOnPrimary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideX(
          begin: 0.05,
          duration: 400.ms,
          delay: 600.ms,
          curve: Curves.easeOut,
        );
  }

  // ── Upload Progress ─────────────────────────────────────────

  Widget _buildUploadProgress() {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          // Animated icon
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(
                  value: _uploadProgress,
                  strokeWidth: 3,
                  backgroundColor: AppColors.surfaceBorder,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ],
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1500.ms,
                color: AppColors.primary.withOpacity(0.15),
              ),
          const SizedBox(height: AppSpacing.lg),

          // Progress percentage
          Text(
            '${(_uploadProgress * 100).toInt()}%',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Status text
          Text(
            _uploadStatusText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          if (_selectedFileName != null)
            Text(
              _selectedFileName!,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          const SizedBox(height: AppSpacing.lg),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceBorder,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Steps indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStep('Upload', _uploadProgress >= 0.15),
              _buildProgressDot(_uploadProgress >= 0.35),
              _buildProgressStep('Process', _uploadProgress >= 0.35),
              _buildProgressDot(_uploadProgress >= 0.55),
              _buildProgressStep('Extract', _uploadProgress >= 0.55),
              _buildProgressDot(_uploadProgress >= 0.90),
              _buildProgressStep('Done', _uploadProgress >= 0.90),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.95, 0.95),
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildProgressStep(String label, bool active) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.surfaceBorder,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? AppColors.primary : AppColors.textTertiary,
              width: 1.5,
            ),
          ),
          child: active
              ? const Icon(Icons.check_rounded,
                  size: 14, color: AppColors.primary)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDot(bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: 16,
        height: 2,
        color: active ? AppColors.primary : AppColors.surfaceBorder,
      ),
    );
  }

  // ── Recent Uploads ──────────────────────────────────────────

  Widget _buildRecentUploads() {
    if (_recentUploads.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.upload_file_rounded,
                size: 40, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No uploads yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your uploaded documents will appear here',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 800.ms);
    }

    return Column(
      children: _recentUploads.asMap().entries.map((entry) {
        final idx = entry.key;
        final upload = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildRecentUploadItem(upload),
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: 750 + idx * 80))
            .slideX(
              begin: 0.05,
              delay: Duration(milliseconds: 750 + idx * 80),
              duration: 350.ms,
              curve: Curves.easeOut,
            );
      }).toList(),
    );
  }

  Widget _buildRecentUploadItem(Map<String, dynamic> upload) {
    IconData typeIcon;
    Color typeColor;

    switch (upload['type']) {
      case 'pdf':
        typeIcon = Icons.picture_as_pdf_rounded;
        typeColor = const Color(0xFFFF4444);
        break;
      case 'image':
        typeIcon = Icons.image_rounded;
        typeColor = const Color(0xFF4EA8FF);
        break;
      case 'url':
        typeIcon = Icons.link_rounded;
        typeColor = AppColors.accent;
        break;
      default:
        typeIcon = Icons.insert_drive_file_rounded;
        typeColor = AppColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upload['name'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  upload['date'] ?? '',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          StatusPill(status: upload['status'] ?? 'unknown'),
        ],
      ),
    );
  }
}

// ── Animated Dotted Border Painter ────────────────────────────

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;
  final double dashOffset;

  _DottedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.radius,
    this.dashOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      final length = metric.length;
      final dashLength = gap;
      double distance = dashOffset % (dashLength * 2);

      while (distance < length) {
        final start = distance;
        final end = (distance + dashLength).clamp(0.0, length);
        final extractPath = metric.extractPath(start, end);
        canvas.drawPath(extractPath, paint);
        distance += dashLength * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return oldDelegate.dashOffset != dashOffset ||
        oldDelegate.color != color;
  }
}
