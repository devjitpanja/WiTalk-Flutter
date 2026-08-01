import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Persistent overlay widget that mirrors the RN GoogleAIBottomSheet exactly.
///
/// - [visible]       → slides in/out
/// - [onMinimize]    → caller hides (visible=false); WebView session preserved;
///                     caller also clears [initialQuery]
/// - [onClose]       → caller hides AND resets state + clears [initialQuery]
/// - [roomContext]   → appended to the Latest News prompt
/// - [initialQuery]  → when non-null on open, skips starters and goes straight
///                     to a Google AI search with this query (mirrors onAskGemini path)
class GoogleAIBottomSheet extends StatefulWidget {
  final bool visible;
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;
  final String? roomContext;
  final String? initialQuery;

  const GoogleAIBottomSheet({
    super.key,
    required this.visible,
    this.onMinimize,
    this.onClose,
    this.roomContext,
    this.initialQuery,
  });

  @override
  State<GoogleAIBottomSheet> createState() => _GoogleAIBottomSheetState();
}

class _GoogleAIBottomSheetState extends State<GoogleAIBottomSheet>
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

  // ── Search input ──────────────────────────────────────────────────────────────
  final TextEditingController _queryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    if (widget.visible) _openSheet();
  }

  @override
  void didUpdateWidget(GoogleAIBottomSheet old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _openSheet();
    if (!widget.visible && old.visible) _closeAnim();
  }

  void _openSheet() {
    _everOpened = true;

    if (widget.initialQuery != null) {
      // Skip starters, go directly to search
      _showStarters = false;
      _isLoading = true;
      _launchWebView(
          'https://www.google.com/search?q=${Uri.encodeComponent(widget.initialQuery!)}&udm=50&gl=us&hl=en');
    } else {
      if (!_hasLoadedOnce) {
        _isLoading = true;
        _showStarters = true;
      }
    }

    _animCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.fastOutSlowIn);
  }

  void _closeAnim() {
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
      _queryCtrl.clear();
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

  // ── Latest News ───────────────────────────────────────────────────────────────
  void _handleLatestNews() {
    final now = DateTime.now();
    final dateStr =
        '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}, ${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    String finalPrompt =
        'Current Date & Time: $dateStr at $timeStr\n\nI\'m in a WiTalk audio room and we want to discuss current events. Find the latest top trending news from today and suggest interesting discussion topics based on these news stories. Include:\n1. Brief summary of top 3-5 trending news stories\n2. Discussion questions for each story\n3. Different perspectives to explore\n4. Fun facts or additional context\n\nMake it engaging and suitable for audio room conversation!';

    if (widget.roomContext != null) {
      finalPrompt = '$finalPrompt\n\nRoom Context: ${widget.roomContext}';
    }

    setState(() {
      _showStarters = false;
      _isLoading = true;
    });

    final url =
        'https://www.google.com/search?q=${Uri.encodeComponent(finalPrompt)}&udm=50&gl=us&hl=en';
    _launchWebView(url);
  }

  // ── Custom search ─────────────────────────────────────────────────────────────
  void _handleCustomSearch() {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _showStarters = false;
      _isLoading = true;
      _queryCtrl.clear();
    });

    final url =
        'https://www.google.com/search?q=${Uri.encodeComponent(q)}&udm=50&gl=us&hl=en';
    _launchWebView(url);
  }

  void _launchWebView(String url) {
    final ctrl = WebViewController();
    ctrl.setJavaScriptMode(JavaScriptMode.unrestricted);
    ctrl.setUserAgent(Platform.isAndroid
        ? 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.200 Mobile Safari/537.36'
        : 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1');
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
      onWebResourceError: (_) {
        if (mounted) setState(() => _isLoading = false);
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
    _queryCtrl.dispose();
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
                    // ── Handle ─────────────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0751DF).withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // ── Header ─────────────────────────────────────────────
                    _GoogleAIHeader(
                      onMinimize: _handleMinimize,
                      onClose: _handleClose,
                    ),

                    // ── Content ────────────────────────────────────────────
                    Expanded(
                      child: _showStarters && !_hasLoadedOnce
                          ? _GoogleStartersScreen(
                              queryCtrl: _queryCtrl,
                              onLatestNews: _handleLatestNews,
                              onCustomSearch: _handleCustomSearch,
                              bottomPad: bottomPad,
                            )
                          : _GoogleWebViewScreen(
                              controller: _webCtrl,
                              isLoading: _isLoading,
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
// Google AI specific sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _GoogleAIHeader extends StatelessWidget {
  final VoidCallback? onMinimize;
  final VoidCallback? onClose;

  const _GoogleAIHeader({this.onMinimize, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.search, size: 18, color: Color(0xFF4285F4)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Google AI',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
                color: const Color(0xFFC8D2FF).withOpacity(0.9),
              ),
            ),
          ),
          GestureDetector(
            onTap: onMinimize,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.minimize, size: 20,
                  color: const Color(0xFFC8D2FF).withOpacity(0.8)),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 20,
                  color: const Color(0xFFC8D2FF).withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleStartersScreen extends StatelessWidget {
  final TextEditingController queryCtrl;
  final VoidCallback onLatestNews;
  final VoidCallback onCustomSearch;
  final double bottomPad;

  const _GoogleStartersScreen({
    required this.queryCtrl,
    required this.onLatestNews,
    required this.onCustomSearch,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 32, 20, bottomPad + 20),
      children: [
        Text(
          'Quick Google Search',
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
          'Get latest news or search anything',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Outfit',
            color: const Color(0xFFC8D2FF).withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Latest News button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onLatestNews,
            borderRadius: BorderRadius.circular(14),
            splashColor: const Color(0xFF4285F4).withOpacity(0.3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF4285F4).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Text('📰', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Latest News',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                        color: const Color(0xFFC8D2FF).withOpacity(0.9),
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 20,
                      color: const Color(0xFFC8D2FF).withOpacity(0.6)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Custom query section
        Text(
          'Or search your own query',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Outfit',
            color: const Color(0xFFC8D2FF).withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4285F4).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20,
                  color: const Color(0xFFC8D2FF).withOpacity(0.4)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: queryCtrl,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    color: const Color(0xFFC8D2FF).withOpacity(0.95),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type your search query...',
                    hintStyle: TextStyle(
                        color: const Color(0xFFC8D2FF).withOpacity(0.4),
                        fontFamily: 'Outfit'),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onCustomSearch(),
                  autocorrect: false,
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: queryCtrl,
                builder: (_, val, __) {
                  if (val.text.trim().isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: onCustomSearch,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.send,
                          size: 18, color: Color(0xFF4285F4)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoogleWebViewScreen extends StatelessWidget {
  final WebViewController? controller;
  final bool isLoading;
  final double bottomPad;

  const _GoogleWebViewScreen({
    required this.controller,
    required this.isLoading,
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
                  const CircularProgressIndicator(
                      color: Color(0xFF4285F4), strokeWidth: 2.5),
                  const SizedBox(height: 12),
                  Text(
                    'Loading Google AI...',
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
