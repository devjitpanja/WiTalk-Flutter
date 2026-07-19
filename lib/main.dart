import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase — google-services.json is in android/app/
  await Firebase.initializeApp();

  // Push notifications (OneSignal)
  await notificationService.initialize();

  runApp(const ProviderScope(child: WiTalkApp()));
}

class WiTalkApp extends ConsumerStatefulWidget {
  const WiTalkApp({super.key});

  @override
  ConsumerState<WiTalkApp> createState() => _WiTalkAppState();
}

class _WiTalkAppState extends ConsumerState<WiTalkApp> {
  bool _locationStartupDone = false;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    // Connect Socket.IO & run location startup when authenticated
    ref.listen(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        socketService.connect();
        final uid = next.uid;
        if (uid != null) {
          notificationService.setExternalUserId(uid);
          if (!_locationStartupDone) {
            _locationStartupDone = true;
            _runLocationStartup(uid);
          }
        }
      } else if (next.status == AuthStatus.unauthenticated) {
        socketService.disconnect();
        notificationService.logout();
        locationService.stopTracking();
        _locationStartupDone = false;
      }
    });

    return MaterialApp.router(
      title: 'WiTalk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  /// Mirrors RN App.jsx boot sequence: warm cache → forced update → start tracker.
  Future<void> _runLocationStartup(String uid) async {
    final granted = await locationService.checkPermission();
    if (!granted) {
      // Permission not yet granted — LocationPermissionScreen will handle it
      // after onboarding completes. Still try city update via IP fallback.
      return;
    }
    // Warm cache first (OS fix, no GPS spin-up)
    await locationService.warmCache();
    // Fire-and-forget: update city on profile + full location update
    locationService.updateCityOnStartup(uid);
    locationService.getCurrentLocationAndUpdate(uid, forceUpdate: true);
    locationService.startTracking(uid);
  }

  @override
  void dispose() {
    locationService.stopTracking();
    super.dispose();
  }
}
