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
import 'providers/chat_provider.dart';
import 'services/chat_api_service.dart';
import 'services/message_sync_manager.dart';

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

    // Connect Socket.IO, initialize chat provider & run location startup when authenticated
    ref.listen(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated &&
          prev?.status != AuthStatus.authenticated) {
        final uid = next.uid;
        if (uid != null) {
          _initChatSystem(uid);
          notificationService.setExternalUserId(uid);
          if (!_locationStartupDone) {
            _locationStartupDone = true;
            _runLocationStartup(uid);
          }
        }
      } else if (next.status == AuthStatus.unauthenticated) {
        socketService.disconnect();
        messageSyncManager.cleanup();
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

  /// Wire socket → chatProvider → load initial conversations + groups.
  Future<void> _initChatSystem(String uid) async {
    try {
      // 1. Connect socket
      final socket = await socketService.connect();

      // 2. Wire socket into chatProvider so it receives all events
      ref.read(chatProvider.notifier).init(socket, uid);

      // 3. Initialize offline sync manager
      final db = ref.read(appDatabaseProvider);
      await messageSyncManager.initialize(socket, uid, db);

      // 4. Load conversations + groups from API (parallel)
      final apiService = chatApiService;
      final results = await Future.wait([
        apiService.getConversations(uid).catchError((_) => <Map<String, dynamic>>[]),
        apiService.getUserGroups(uid).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final convs = (results[0] as List<Map<String, dynamic>>)
          .map((e) => ChatConversation.fromJson(e))
          .toList();
      final groups = (results[1] as List<Map<String, dynamic>>)
          .map((e) => ChatConversation.fromJson(e))
          .toList();

      ref.read(chatProvider.notifier).setConversations(convs);
      ref.read(chatProvider.notifier).setGroups(groups);

      // 5. Sync any pending offline actions now that socket is ready
      messageSyncManager.onSocketReady();
    } catch (e) {
      debugPrint('[Chat] Init error: $e');
    }
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
