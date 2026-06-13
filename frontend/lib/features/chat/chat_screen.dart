import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

enum MessageRole { user, assistant }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<SourceCitation> citations;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.citations = const [],
  });

  Map<String, dynamic> toHistoryJson() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': content,
      };
}

class SourceCitation {
  final String label; // e.g. "Page 3", "Section: Eligibility"
  final String? type; // "page" | "section"

  const SourceCitation({required this.label, this.type});
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Screen
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // ── State ─────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];
  final ApiService _apiService = ApiService();
  bool _isTyping = false;
  bool _hasText = false;
  String? _opportunityId;
  String _opportunityName = 'AI Mentor';
  bool _initialised = false;

  // ── Suggested Questions ───────────────────────────────────────
  final List<String> _suggestedQuestions = [
    'Summarize the key requirements',
    'Am I eligible for this?',
    'What are the important deadlines?',
    'What documents do I need?',
    'How do I prepare my application?',
    'What makes a strong candidate?',
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _opportunityId = args['opportunityId'] as String?;
        _opportunityName =
            (args['opportunityName'] as String?) ?? 'AI Mentor';
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _apiService.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent + 80;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  List<SourceCitation> _parseCitations(Map<String, dynamic> response) {
    final raw = response['citations'] ?? response['sources'];
    if (raw == null) return [];
    if (raw is List) {
      return raw.map<SourceCitation>((c) {
        if (c is Map) {
          return SourceCitation(
            label: c['label']?.toString() ??
                c['source']?.toString() ??
                'Source',
            type: c['type']?.toString(),
          );
        }
        return SourceCitation(label: c.toString());
      }).toList();
    }
    return [];
  }

  // ── Send Message ──────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();
    _inputFocusNode.requestFocus();

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final history =
          _messages.map((m) => m.toHistoryJson()).toList();

      final response = await _apiService.sendChatMessage(
        opportunityId: _opportunityId ?? '',
        message: text.trim(),
        history: history,
      );

      final aiContent = response['response']?.toString() ??
          response['message']?.toString() ??
          response['answer']?.toString() ??
          'I couldn\'t generate a response. Please try again.';

      final citations = _parseCitations(response);

      final aiMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role: MessageRole.assistant,
        content: aiContent,
        timestamp: DateTime.now(),
        citations: citations,
      );

      setState(() {
        _messages.add(aiMsg);
        _isTyping = false;
      });
    } catch (e) {
      final errorMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role: MessageRole.assistant,
        content:
            'Sorry, I encountered an error. Please check your connection and try again.',
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(errorMsg);
        _isTyping = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Chat messages
          Expanded(child: _buildMessageList()),

          // Suggested questions (only before any messages)
          if (_messages.isEmpty) _buildSuggestedQuestions(),

          // Typing indicator
          if (_isTyping) _buildTypingIndicator(),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface.withOpacity(0.8),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.transparent),
        ),
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.textOnPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Mentor',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _opportunityName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _showClearDialog(),
          icon: Icon(Icons.refresh_rounded,
              size: 20, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showClearDialog() {
    if (_messages.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Text('Clear Chat',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Start a new conversation?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _messages.clear());
            },
            child: const Text('Clear',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Message List ──────────────────────────────────────────────

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg.role == MessageRole.user;

        // Show small timestamp divider when gap > 5 min
        Widget? timeDivider;
        if (index > 0) {
          final prev = _messages[index - 1];
          if (msg.timestamp.difference(prev.timestamp).inMinutes > 5) {
            timeDivider = _buildTimeDivider(msg.timestamp);
          }
        } else if (index == 0) {
          timeDivider = _buildTimeDivider(msg.timestamp);
        }

        return Column(
          children: [
            if (timeDivider != null) timeDivider,
            isUser
                ? _buildUserBubble(msg, index)
                : _buildAiBubble(msg, index),
          ],
        );
      },
    );
  }

  Widget _buildTimeDivider(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        '$hour:$min',
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 40,
                color: AppColors.textOnPrimary,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.06, duration: 2000.ms, curve: Curves.easeInOut),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Ask me anything',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'I\'ve read the document and I\'m ready\nto help you understand every detail.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.15),
      ),
    );
  }

  // ── User Bubble ───────────────────────────────────────────────

  Widget _buildUserBubble(ChatMessage msg, int index) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(
          bottom: AppSpacing.sm,
          left: AppSpacing.xxl,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.lg),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          msg.content,
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.15, curve: Curves.easeOutCubic);
  }

  // ── AI Bubble ─────────────────────────────────────────────────

  Widget _buildAiBubble(ChatMessage msg, int index) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.only(
          bottom: AppSpacing.sm,
          right: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI avatar + glass card
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Small avatar
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Bubble
                Flexible(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(AppRadius.lg),
                            bottomLeft: Radius.circular(AppRadius.lg),
                            bottomRight: Radius.circular(AppRadius.lg),
                          ),
                          border: Border.all(
                            color: AppColors.glassBorder,
                            width: 1,
                          ),
                        ),
                        child: MarkdownBody(
                          data: msg.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.5,
                              height: 1.55,
                            ),
                            h1: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            h2: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            h3: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            strong: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            em: TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            code: TextStyle(
                              color: AppColors.accent,
                              backgroundColor:
                                  AppColors.accent.withOpacity(0.1),
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                  color: AppColors.surfaceBorder),
                            ),
                            listBullet: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: AppColors.primary.withOpacity(0.5),
                                  width: 3,
                                ),
                              ),
                            ),
                            blockquotePadding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              top: AppSpacing.xs,
                              bottom: AppSpacing.xs,
                            ),
                            a: const TextStyle(
                              color: AppColors.info,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Citations
            if (msg.citations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: 36,
                  top: AppSpacing.sm,
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: msg.citations.map((c) {
                    return _buildCitationChip(c);
                  }).toList(),
                ),
              ),

            // Copy button
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: Row(
                children: [
                  _buildActionChip(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: msg.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Copied to clipboard'),
                          backgroundColor: AppColors.surface,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.1, curve: Curves.easeOutCubic);
  }

  Widget _buildCitationChip(SourceCitation citation) {
    final isPage = citation.type == 'page' ||
        citation.label.toLowerCase().contains('page');

    return GestureDetector(
      onTap: () {
        // Could navigate to specific page or section in future
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Source: ${citation.label}'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: AppColors.info.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPage
                  ? Icons.description_outlined
                  : Icons.bookmark_border_rounded,
              size: 12,
              color: AppColors.info,
            ),
            const SizedBox(width: 4),
            Text(
              'Source: ${citation.label}',
              style: const TextStyle(
                color: AppColors.info,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Typing Indicator ──────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          bottom: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md - 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      return Container(
                        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                        child: _AnimatedDot(delay: i * 200),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ── Suggested Questions ───────────────────────────────────────

  Widget _buildSuggestedQuestions() {
    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Suggested questions',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _suggestedQuestions.asMap().entries.map((entry) {
              return _buildSuggestionPill(entry.value, entry.key);
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.15);
  }

  Widget _buildSuggestionPill(String question, int index) {
    return GestureDetector(
      onTap: () => _sendMessage(question),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                question,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, delay: Duration(milliseconds: 100 * index))
        .slideX(begin: 0.08);
  }

  // ── Input Bar ─────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _inputFocusNode,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask about this opportunity...',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 15,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md - 2,
                      ),
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Send button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: _hasText && !_isTyping
                      ? AppColors.primaryGradient
                      : null,
                  color: _hasText && !_isTyping
                      ? null
                      : AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: _hasText && !_isTyping
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: _hasText && !_isTyping
                        ? () => _sendMessage(_textController.text)
                        : null,
                    child: Center(
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: _hasText && !_isTyping
                            ? AppColors.textOnPrimary
                            : AppColors.textTertiary,
                        size: 22,
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Animated Dot (Typing Indicator)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _animation.value),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Color.lerp(
                AppColors.textTertiary,
                AppColors.accent,
                _animation.value,
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
