import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/location_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends ConsumerState<LocationPermissionScreen> {
  bool _loading = false;

  Future<void> _handleAllow() async {
    setState(() => _loading = true);
    final granted =
        await ref.read(locationPermissionProvider.notifier).requestPermission();
    await ref.read(locationPermissionProvider.notifier).markScreenSeen();
    final uid = ref.read(authProvider).uid;
    if (granted && uid != null) {
      locationService.warmCache().then((_) {
        locationService.getCurrentLocationAndUpdate(uid, forceUpdate: true);
        locationService.startTracking(uid);
      });
    }
    if (mounted) context.go('/home');
  }

  Future<void> _handleSkip() async {
    await ref.read(locationPermissionProvider.notifier).markScreenSeen();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header — Skip top-right
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _loading ? null : _handleSkip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                          color: colors.textTertiary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Hero image
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Image.asset(
                isDark
                    ? 'assets/images/dark-location.png'
                    : 'assets/images/light-location.png',
                width: 260,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),

            // Title + subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 24,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                        letterSpacing: -0.2,
                      ),
                      children: [
                        const TextSpan(text: 'Discover more '),
                        TextSpan(
                          text: 'around you',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' 😍'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Allow location access to find nearby people, live adda rooms, events and communities happening around you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Features card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (int i = 0; i < _features.length; i++) ...[
                      _FeatureRow(feature: _features[i], colors: colors),
                      if (i < _features.length - 1)
                        Container(
                          height: 1,
                          color: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFE2E8F0),
                          margin: const EdgeInsets.only(left: 52),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Privacy row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, size: 16, color: AppColors.success),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: ' We respect your privacy.',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Your location is never shared with others.',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Outfit',
                color: colors.textSecondary,
              ),
            ),

            const Spacer(),

            // Footer — CTA + hint
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleAllow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5BDB),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on,
                                    size: 18, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Allow Location Access',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '🔒 You can change this anytime in Settings',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      color: colors.textSecondary,
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

const _features = [
  _Feature(
    bgColor: Color(0xFF3B5BDB),
    icon: Icons.people,
    label: 'Nearby People',
    desc: 'Meet and connect with real people near you',
  ),
  _Feature(
    bgColor: Color(0xFF7C3AED),
    icon: Icons.groups,
    label: 'Local Communities',
    desc: 'Join communities that match your interests',
  ),
  _Feature(
    bgColor: Color(0xFF16A34A),
    icon: Icons.mic,
    label: 'Live Adda Rooms',
    desc: 'Join live voice rooms happening nearby',
  ),
  _Feature(
    bgColor: Color(0xFFDC2626),
    icon: Icons.event,
    label: 'Events & Activities',
    desc: 'Never miss exciting local events & moments',
  ),
];

class _Feature {
  final Color bgColor;
  final IconData icon;
  final String label;
  final String desc;

  const _Feature({
    required this.bgColor,
    required this.icon,
    required this.label,
    required this.desc,
  });
}

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  final ThemeColors colors;

  const _FeatureRow({required this.feature, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: feature.bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  feature.desc,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    color: colors.textSecondary,
                    height: 1.33,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.check, size: 20, color: Color(0xFF3B82F6)),
        ],
      ),
    );
  }
}
