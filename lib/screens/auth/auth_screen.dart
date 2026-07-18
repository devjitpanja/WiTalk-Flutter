import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
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

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _loading = false;
  List<_Star>? _stars;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stars == null) {
      final size = MediaQuery.of(context).size;
      _stars = _buildStars(size.width, size.height);
    }
  }

  String? _error;

  Future<void> _handleGoogleSignIn() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });

    final result = await AuthService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success && result.uid != null) {
      // Update auth state — this triggers the router redirect automatically
      await ref.read(authProvider.notifier).signIn(uid: result.uid!);
      // Router will redirect based on auth state; navigate to onboarding if needed
      if (mounted && result.nextRoute != null && result.nextRoute != '/home') {
        context.go(result.nextRoute!);
      }
    } else if (result.error == 'cancelled') {
      // user dismissed picker — no message needed
    } else if (result.error != null && result.error!.startsWith('banned:')) {
      _showError('Your account has been banned. Contact support@witalk.in to appeal.');
    } else {
      _showError(result.error ?? 'Sign-in failed. Please try again.');
    }
  }

  void _showError(String msg) {
    setState(() => _error = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
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
          ],
        ),
      ),
    );
  }
}
