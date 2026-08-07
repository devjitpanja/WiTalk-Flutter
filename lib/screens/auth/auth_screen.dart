import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/ban_check_service.dart';
import '../../providers/auth_provider.dart';

// Pre-computed star positions using golden-angle spread (matches RN implementation)
class _Star {
  final double x, y, size;
  final int delay, duration;
  const _Star(this.x, this.y, this.size, this.delay, this.duration);
}

List<_Star> _buildStars(double w, double h) {
  return List.generate(60, (i) {
    final seed = i * 137.508;
    final x = (sin(seed) * 0.5 + 0.5) * w;
    final y = (cos(seed * 1.3) * 0.5 + 0.5) * h;
    final size = 1.5 + (i % 5) * 0.7;
    final delay = (i * 173) % 2400;
    final duration = 1600 + (i % 7) * 300;
    return _Star(x, y, size, delay, duration);
  });
}

class _GlitterStar extends StatefulWidget {
  final _Star star;
  const _GlitterStar({required this.star});

  @override
  State<_GlitterStar> createState() => _GlitterStarState();
}

class _GlitterStarState extends State<_GlitterStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.star.duration),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(_controller);

    Future.delayed(Duration(milliseconds: widget.star.delay), () {
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
    final s = widget.star;
    return Positioned(
      left: s.x - s.size,
      top: s.y - s.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final t = _anim.value;
          final opacity = t < 0.5
              ? 0.08 + (t / 0.5) * (1.0 - 0.08)
              : 1.0 - ((t - 0.5) / 0.5) * (1.0 - 0.08);
          final scale = t < 0.5
              ? 0.4 + (t / 0.5) * (1.4 - 0.4)
              : 1.4 - ((t - 0.5) / 0.5) * (1.4 - 0.4);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: s.size * 2,
                height: s.size * 2,
                child: Stack(
                  children: [
                    Positioned(
                      left: s.size - s.size * 0.15,
                      top: 0,
                      child: Container(
                        width: s.size * 0.3,
                        height: s.size * 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(s.size * 0.15),
                        ),
                      ),
                    ),
                    Positioned(
                      top: s.size - s.size * 0.15,
                      left: 0,
                      child: Container(
                        width: s.size * 2,
                        height: s.size * 0.3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(s.size * 0.15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AlertConfig {
  final bool visible;
  final String title;
  final String message;
  final String type;
  final bool showContactNow;
  final String? banUserEmail;
  final String? banUserName;

  const _AlertConfig({
    this.visible = false,
    this.title = '',
    this.message = '',
    this.type = 'info',
    this.showContactNow = false,
    this.banUserEmail,
    this.banUserName,
  });

  _AlertConfig copyWith({
    bool? visible,
    String? title,
    String? message,
    String? type,
    bool? showContactNow,
    String? banUserEmail,
    String? banUserName,
  }) => _AlertConfig(
    visible: visible ?? this.visible,
    title: title ?? this.title,
    message: message ?? this.message,
    type: type ?? this.type,
    showContactNow: showContactNow ?? this.showContactNow,
    banUserEmail: banUserEmail,
    banUserName: banUserName,
  );
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _loading = false;
  List<_Star>? _stars;
  _AlertConfig _alert = const _AlertConfig();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForBanMessage());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stars == null) {
      final size = MediaQuery.of(context).size;
      _stars = _buildStars(size.width, size.height);
    }
  }

  /// Mirrors RN AuthScreen.checkForBanMessage():
  /// 1. Show stored ban info from a prior force-logout.
  /// 2. Prefetch ISP + device ban data (populates AuthService cache).
  /// 3. If device is banned, show ban alert immediately.
  Future<void> _checkForBanMessage() async {
    try {
      final banInfo = await BanCheckService.getStoredBanInfo();
      if (banInfo != null) {
        final msg = BanCheckService.getBanMessage(banInfo.reason, banInfo.banUntil);
        _showBanAlert(msg['title']!, msg['message']!, banInfo.userEmail, banInfo.userName);
        await BanCheckService.clearStoredBanInfo();
        // Still prefetch in background so sign-in doesn't need to do it
        prefetchAuthSecurityData();
        return;
      }

      // prefetchAuthSecurityData() runs ISP + device ban checks and caches result
      // in AuthService so the sign-in button press is instant.
      await prefetchAuthSecurityData();

      // Show ban alert if device is already banned (cache is now populated)
      final deviceBan = await BanCheckService.checkAllDeviceBans();
      if (deviceBan.isBanned && mounted) {
        final msg = BanCheckService.getDeviceBanMessage(deviceBan.banReason, deviceBan.banUntil);
        _showBanAlert(msg['title']!, msg['message']!);
      }
    } catch (_) {}
  }

  void _showBanAlert(String title, String message, [String? email, String? name]) {
    if (!mounted) return;
    setState(() {
      _alert = _AlertConfig(
        visible: true,
        title: title,
        message: message,
        type: 'danger',
        showContactNow: true,
        banUserEmail: email,
        banUserName: name,
      );
    });
  }

  void _showError(String title, String message) {
    if (!mounted) return;
    setState(() {
      _alert = _AlertConfig(
        visible: true,
        title: title,
        message: message,
        type: 'danger',
        showContactNow: false,
      );
    });
  }

  void _hideAlert() {
    setState(() => _alert = _alert.copyWith(visible: false));
  }

  Future<void> _handleContactNow() async {
    final email = _alert.banUserEmail;
    final name = _alert.banUserName;

    final userInfoLines = [
      if (name != null && name.isNotEmpty) 'Name: $name',
      if (email != null && email.isNotEmpty) 'Email: $email',
    ].join('\n');

    final body = '''Dear WiTalk Support Team,

I would like to appeal my account ban.

${userInfoLines.isNotEmpty ? 'Account Details:\n$userInfoLines\n\n' : ''}[Please describe your situation here]

Thank you for your support!

Best regards''';

    final uri = Uri(
      scheme: 'mailto',
      path: 'support@witalk.in',
      queryParameters: {
        'subject': 'Account Ban Appeal',
        'body': body,
      },
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showError('Email Client Not Available', 'Please email us at support@witalk.in');
      }
    } catch (_) {
      _showError('Error', 'Failed to open email client.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_loading) return;
    setState(() => _loading = true);

    final result = await AuthService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success && result.uid != null) {
      await ref.read(authProvider.notifier).signIn(uid: result.uid!);
      if (mounted && result.nextRoute != null && result.nextRoute != '/home') {
        context.go(result.nextRoute!);
      }
    } else if (result.error == 'cancelled') {
      // user dismissed picker — no message
    } else if (result.error != null && result.error!.startsWith('banned:')) {
      final reason = result.error!.substring('banned:'.length);
      final msg = BanCheckService.getBanMessage(reason, null);
      _showBanAlert(msg['title']!, msg['message']!);
    } else if (result.error != null && result.error!.startsWith('deviceBanned:')) {
      final reason = result.error!.substring('deviceBanned:'.length);
      final msg = BanCheckService.getDeviceBanMessage(reason, null);
      _showBanAlert(msg['title']!, msg['message']!);
    } else if (result.error != null && result.error!.startsWith('networkBlocked:')) {
      final reason = result.error!.substring('networkBlocked:'.length);
      _showError('Unauthorized Network Detected', reason);
    } else if (result.error != null && result.error!.startsWith('integrityFailed:')) {
      final reason = result.error!.substring('integrityFailed:'.length);
      _showError('App Verification Failed', reason);
    } else {
      _showError('Error', result.error ?? 'Sign-in failed. Please try again.');
    }
  }

  Future<void> _openPolicy() async {
    final uri = Uri.parse('https://policy.witalk.in/');
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleTroubleSigningIn() async {
    final uri = Uri.parse('mailto:support@witalk.in?subject=WiTalk%20Sign-In%20Trouble');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.authGradientTop,
        body: Stack(
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.authGradientTop,
                    AppColors.authGradientMid,
                    AppColors.authGradientBottom,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // Glitter stars
            if (_stars != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    children: _stars!.map((s) => _GlitterStar(star: s)).toList(),
                  ),
                ),
              ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Top — Logo + value prop
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                    child: Column(
                      children: [
                        const Text(
                          'WiTalk',
                          style: TextStyle(
                            fontSize: 64,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Find Your Community',
                          style: TextStyle(
                            fontSize: 26,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Meet people who share your interests, join active communities, and build meaningful friendships.',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w400,
                            color: Color(0xD9FFFFFF),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Middle — illustration
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/login-img.png',
                        width: size.width * 0.82,
                        height: size.width * 0.82,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Bottom — sign in button + terms
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        28, 8, 28, MediaQuery.of(context).padding.bottom + 24),
                    child: Column(
                      children: [
                        // Google sign-in button
                        GestureDetector(
                          onTap: _loading ? null : _handleGoogleSignIn,
                          child: AnimatedOpacity(
                            opacity: _loading ? 0.6 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_loading) ...[
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF1976D2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Signing in...',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ] else ...[
                                    // Google G icon
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFF5F5F5),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'G',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF4285F4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          'Start your journey with communities built around your interests.',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Outfit',
                            color: Color(0xD9FFFFFF),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 10),

                        // Terms + Privacy
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _openPolicy,
                              child: const Text(
                                'Terms',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xBFFFFFFF),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xBFFFFFFF),
                                ),
                              ),
                            ),
                            const Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0x80FFFFFF),
                              ),
                            ),
                            GestureDetector(
                              onTap: _openPolicy,
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xBFFFFFFF),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xBFFFFFFF),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Trouble signing in
                        GestureDetector(
                          onTap: _loading ? null : _handleTroubleSigningIn,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: const Text(
                              'Trouble signing in?',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                color: Color(0xBFFFFFFF),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Ban / error alert dialog — mirrors RN CustomAlertDialog with showContactNow
            if (_alert.visible)
              _BanAlertOverlay(
                title: _alert.title,
                message: _alert.message,
                showContactNow: _alert.showContactNow,
                onDismiss: _hideAlert,
                onContactNow: _handleContactNow,
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen overlay alert that matches RN CustomAlertDialog with
/// the "Contact Now" third-action button used for ban messages.
class _BanAlertOverlay extends StatelessWidget {
  final String title;
  final String message;
  final bool showContactNow;
  final VoidCallback onDismiss;
  final VoidCallback onContactNow;

  const _BanAlertOverlay({
    required this.title,
    required this.message,
    required this.showContactNow,
    required this.onDismiss,
    required this.onContactNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showContactNow)
                        TextButton(
                          onPressed: onContactNow,
                          child: const Text(
                            'Contact Now',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: onDismiss,
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
