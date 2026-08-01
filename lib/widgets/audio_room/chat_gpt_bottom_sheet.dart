import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ── Conversation starters (mirrors RN CONVERSATION_STARTERS) ──────────────────
const _kStarters = [
  {'emoji': '📰', 'title': 'Latest News', 'prompt': null, 'isDynamic': true},
  {
    'emoji': '🔮',
    'title': 'Would You Rather',
    'prompt':
        'I\'m in a WiTalk audio room and we want to play "Would You Rather". Give me interesting, creative, and thought-provoking "Would You Rather" questions that can spark fun debates and discussions. Mix deep, funny, and controversial choices.',
  },
  {
    'emoji': '🎮',
    'title': 'Gaming & Tech Talk',
    'prompt':
        'I\'m in a WiTalk audio room discussing gaming and technology. Suggest trending topics, latest tech news, gaming debates, favorite games discussion, tech predictions, and interesting questions about gaming culture and technology.',
  },
  {
    'emoji': '🎬',
    'title': 'Movies & Shows',
    'prompt':
        'I\'m in a WiTalk audio room talking about movies and TV shows. Suggest popular series discussions, movie recommendations, plot theories, character debates, and fun questions about entertainment and pop culture.',
  },
  {
    'emoji': '💬',
    'title': 'Hot Takes & Opinions',
    'prompt':
        'I\'m in a WiTalk audio room sharing hot takes and controversial opinions. Give me spicy but respectful discussion topics, unpopular opinions, and debate-worthy questions that will get everyone talking.',
  },
  {
    'emoji': '🧠',
    'title': 'Deep Questions',
    'prompt':
        'I\'m in a WiTalk audio room having a deep conversation. Give me thought-provoking questions about life, philosophy, psychology, human nature, existence, and meaningful topics that spark profound discussions.',
  },
  {
    'emoji': '😂',
    'title': 'Fun & Games',
    'prompt':
        'I\'m in a WiTalk audio room looking for fun activities. Suggest interactive games like "Two Truths and a Lie", storytelling games, improv challenges, funny icebreakers, riddles, and entertaining group activities.',
  },
  {
    'emoji': '🌍',
    'title': 'Travel & Culture',
    'prompt':
        'I\'m in a WiTalk audio room discussing travel and different cultures. Suggest conversation topics about travel experiences, cultural differences, dream destinations, food from around the world, and interesting cultural facts.',
  },
  {
    'emoji': '🎯',
    'title': 'Practice English',
    'prompt':
        'I\'m practicing English in a WiTalk audio room. Help me with engaging conversation topics, useful phrases, vocabulary building exercises, pronunciation tips, and discussion questions that help improve English speaking skills.',
  },
  {'emoji': '🌟', 'title': 'Other', 'prompt': null},
];

/// Persistent overlay widget that mirrors the RN ChatGPTBottomSheet exactly.
///
/// - [visible]     → slides in/out
/// - [onMinimize]  → caller hides (sets visible=false); WebView session preserved
/// - [onClose]     → caller hides AND resets state; next open shows starters again
/// - [roomContext] → appended to every prompt
///
/// Must be placed in a [Stack] that covers the full screen (above the scaffold).
class ChatGPTBottomSheet extends StatefulWidget {
  final bool visible;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;
  final String? roomContext;

  const ChatGPTBottomSheet({
    super.key,
    required this.visible,
    this.onMinimize,
    this.onClose,
    this.roomContext,
  });

  @override
  State<ChatGPTBottomSheet> createState() => _ChatGPTBottomSheetState();
}

class _ChatGPTBottomSheetState extends State<ChatGPTBottomSheet>
    with SingleTickerProviderStateMixin {
  // ── Animation ────────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnim;

  // ── WebView state ─────────────────────────────────────────────────────────────
  WebViewController? _webCtrl;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  bool _everOpened = false;
  bool _showStarters = true;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    if (widget.visible) _openSheet();
  }

  @override
  void didUpdateWidget(ChatGPTBottomSheet old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _openSheet();
    if (!widget.visible && old.visible) _closeSheet();
  }

  void _openSheet() {
    _everOpened = true;
    if (!_hasLoadedOnce) {
      _isLoading = true;
      _showStarters = true;
    }
    // Spring-like: use fastOutSlowIn for open
    _animCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.fastOutSlowIn);
  }

  void _closeSheet() {
    _animCtrl.animateTo(0.0,
        duration: const Duration(milliseconds: 260), curve: Curves.easeIn);
  }

  // ── Minimize: caller sets visible=false, state preserved ────────────────────
  void _handleMinimize() => widget.onMinimize?.call();

  // ── Close: fully reset so next open shows starters ──────────────────────────
  void _handleClose() {
    setState(() {
      _hasLoadedOnce = false;
      _isLoading = true;
      _everOpened = false;
      _showStarters = true;
      _webCtrl = null;
      _canGoBack = false;
    });
    widget.onClose?.call();
  }

  // ── Back button (Android): go back in WebView or minimize ────────────────────
  Future<bool> _handleAndroidBack() async {
    if (!widget.visible) return false;
    if (_canGoBack && _webCtrl != null) {
      await _webCtrl!.goBack();
      return true;
    }
    _handleMinimize();
    return true;
  }

  // ── Starter pressed ───────────────────────────────────────────────────────────
  void _handleStarterPress(Map<String, Object?> starter) {
    setState(() {
      _showStarters = false;
      _isLoading = true;
    });

    String? finalPrompt = starter['prompt'] as String?;

    if (starter['isDynamic'] == true && starter['title'] == 'Latest News') {
      final now = DateTime.now();
      final dateStr =
          '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}, ${now.year}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      finalPrompt =
          'Current Date & Time: $dateStr at $timeStr\n\nI\'m in a WiTalk audio room and we want to discuss current events. Find the latest top trending news from today and suggest interesting discussion topics based on these news stories. Include:\n1. Brief summary of top 3-5 trending news stories\n2. Discussion questions for each story\n3. Different perspectives to explore\n4. Fun facts or additional context\n\nMake it engaging and suitable for audio room conversation!';
    }

    String url = 'https://chatgpt.com/';
    if (finalPrompt != null) {
      if (widget.roomContext != null) {
        finalPrompt = '$finalPrompt\n\nRoom Context: ${widget.roomContext}';
      }
      final encoded = Uri.encodeComponent(finalPrompt);
      url = 'https://chatgpt.com/?prompt=$encoded';
    }

    _launchWebView(url);
  }

  void _launchWebView(String url) {
    final ctrl = WebViewController();
    ctrl.setJavaScriptMode(JavaScriptMode.unrestricted);
    ctrl.setUserAgent(Platform.isAndroid
        ? 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36'
        : null);
    ctrl.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) async {
        final canGoBack = await ctrl.canGoBack();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasLoadedOnce = true;
            _canGoBack = canGoBack;
          });
        }
      },
      onNavigationRequest: (req) => NavigationDecision.navigate,
    ));
    ctrl.loadRequest(Uri.parse(url));
    setState(() => _webCtrl = ctrl);
  }

  // ── Date helpers ──────────────────────────────────────────────────────────────
  static String _weekday(int d) => const [
        '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
      ][d];

  static String _month(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_everOpened) return const SizedBox.shrink();

    final screenH = MediaQuery.of(context).size.height;
    final sheetH = screenH * 0.9;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: BackButtonListener(
          onBackButtonPressed: _handleAndroidBack,
          child: SlideTransition(
            position: _slideAnim,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: sheetH + bottomPad,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1017),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(
                    color: const Color(0xFF0751DF).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // ── Drag handle ────────────────────────────────────────
                    _DragHandle(),

                    // ── Header ─────────────────────────────────────────────
                    _Header(
                      iconColor: const Color(0xFF10A37F),
                      icon: Icons.psychology,
                      title: 'ChatGPT',
                      onMinimize: _handleMinimize,
                      onClose: _handleClose,
                    ),

                    // ── Content ────────────────────────────────────────────
                    Expanded(
                      child: _showStarters && !_hasLoadedOnce
                          ? _StartersScreen(
                              starters: _kStarters,
                              onStarterPress: _handleStarterPress,
                            )
                          : _WebViewScreen(
                              controller: _webCtrl,
                              isLoading: _isLoading,
                              loadingColor: const Color(0xFF10A37F),
                              loadingText: 'Loading ChatGPT...',
                              bottomPad: bottomPad,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF0751DF).withOpacity(0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;

  const _Header({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.onMinimize,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
                color: const Color(0xFFC8D2FF).withOpacity(0.9),
              ),
            ),
          ),
          _HeaderBtn(icon: Icons.minimize, onTap: onMinimize),
          const SizedBox(width: 4),
          _HeaderBtn(icon: Icons.close, onTap: onClose),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: const Color(0xFFC8D2FF).withOpacity(0.8)),
      ),
    );
  }
}

class _StartersScreen extends StatelessWidget {
  final List<Map<String, Object?>> starters;
  final void Function(Map<String, Object?>) onStarterPress;

  const _StartersScreen({required this.starters, required this.onStarterPress});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
      children: [
        Text(
          'Start a Conversation',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
            color: const Color(0xFFC8D2FF).withOpacity(0.95),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a conversation style or start fresh',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Outfit',
            color: const Color(0xFFC8D2FF).withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        ...starters.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onStarterPress(s),
                  borderRadius: BorderRadius.circular(14),
                  splashColor: const Color(0xFF0751DF).withOpacity(0.3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0751DF).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF0751DF).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(s['emoji'] as String,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s['title'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                              color: const Color(0xFFC8D2FF).withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class _WebViewScreen extends StatelessWidget {
  final WebViewController? controller;
  final bool isLoading;
  final Color loadingColor;
  final String loadingText;
  final double bottomPad;

  const _WebViewScreen({
    required this.controller,
    required this.isLoading,
    required this.loadingColor,
    required this.loadingText,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (controller != null)
          WebViewWidget(controller: controller!)
        else
          const SizedBox.shrink(),

        if (isLoading)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0D1017),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: loadingColor, strokeWidth: 2.5),
                  const SizedBox(height: 12),
                  Text(
                    loadingText,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Outfit',
                      color: const Color(0xFFC8D2FF).withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
