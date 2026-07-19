import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
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
    await ref.read(locationPermissionProvider.notifier).markScreenSeen();
    final granted =
        await ref.read(locationPermissionProvider.notifier).requestPermission();
    final uid = ref.read(authProvider).uid;
    if (granted && uid != null) {
      // Fire-and-forget: warm cache then update server
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              // Icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: AppColors.primary, size: 48),
              ),
              const SizedBox(height: 28),
              const Text(
                'Discover people\nnear you',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'WiTalk uses your location to connect you\nwith people and communities nearby.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Outfit',
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              // Feature list
              _FeatureRow(
                icon: Icons.people,
                color: const Color(0xFF22C55E),
                title: 'Nearby People',
                subtitle: 'Find like-minded people around you',
              ),
              const SizedBox(height: 20),
              _FeatureRow(
                icon: Icons.groups,
                color: AppColors.primary,
                title: 'Local Communities',
                subtitle: 'Join communities in your city',
              ),
              const SizedBox(height: 20),
              _FeatureRow(
                icon: Icons.mic,
                color: const Color(0xFFF59E0B),
                title: 'Live Adda Rooms',
                subtitle: 'Connect with locals in live rooms',
              ),
              const SizedBox(height: 20),
              _FeatureRow(
                icon: Icons.event,
                color: const Color(0xFF8B5CF6),
                title: 'Events & Activities',
                subtitle: 'Discover local events near you',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleAllow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text(
                          'Allow Location Access',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _loading ? null : _handleSkip,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      color: AppColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}
