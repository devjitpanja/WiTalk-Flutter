import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/create_action_provider.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'providers/chat_provider.dart';
import 'services/chat_api_service.dart';
import 'services/message_sync_manager.dart';
import 'services/global_video_settings.dart';
import 'services/deep_link_service.dart';
import 'services/ban_check_service.dart';
import 'api/channel_api.dart';
import 'api/dio_client.dart';
import 'utils/screenshot_prevention.dart';
import 'utils/security_profile.dart';
import 'utils/storage.dart';
import 'utils/logger.dart';
import 'widgets/common/screenshot_privacy_sheet.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'screens/chat/join_group_screen.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Firebase — google-services.json is in android/app/
  await Firebase.initializeApp();

  // Start offline network monitor (connectivity_plus listener)
  initNetworkMonitor();

  // Push notifications (OneSignal)
  await notificationService.initialize();

  // Load persisted video mute preference
  await globalVideoSettings.init();

  // Fire visibility updates quickly so video play/pause reacts without noticeable lag
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 100);

  runApp(const ProviderScope(child: WiTalkApp()));
}

class WiTalkApp extends ConsumerStatefulWidget {
  const WiTalkApp({super.key});

  @override
  ConsumerState<WiTalkApp> createState() => _WiTalkAppState();
}

// Root navigator key — provides a stable BuildContext for deep link and
// notification navigation after the widget tree is fully mounted.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class _WiTalkAppState extends ConsumerState<WiTalkApp> with WidgetsBindingObserver {
  bool _locationStartupDone = false;
  bool _chatInitialized = false;
  bool _deepLinkInitialized = false;
  bool _securityProfileSentThisSession = false;

  // Periodic ban check — once per 5 minutes when app is in foreground
  static const _banCheckInterval = Duration(minutes: 5);
  DateTime? _lastBanCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitUser();
      _checkAndInitChat();
      _initDeepLinks();
      _initScreenshotListener();
      _runSecurityChecks(reason: 'app_open');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset so security profile is sent again on this foreground
      _securityProfileSentThisSession = false;
      _runSecurityChecks(reason: 'foreground');
      _runPeriodicBanCheck();
    }
  }

  void _initScreenshotListener() {
    if (Platform.isIOS) {
      startScreenshotListener((event) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && mounted) {
          ScreenshotPrivacySheet.show(ctx);
        }
      });
    }
    // Android: FLAG_SECURE is applied by ScreenshotPreventPlugin automatically on attach.
    // No listener needed — the OS blocks the capture outright.
  }

  Future<void> _runSecurityChecks({required String reason}) async {
    if (_securityProfileSentThisSession) return;
    _securityProfileSentThisSession = true;

    final uid = await AppStorage.get('uid') as String?;

    // Check security flags (VPN, emulator, Frida) and send profile
    // All handled inside collectAndSendSecurityProfile — fire and forget
    collectAndSendSecurityProfile(userId: uid, updateReason: reason).then((_) {
      AppLogger.log('[Security] Profile sent (reason=$reason)');
    });
  }

  Future<void> _runPeriodicBanCheck() async {
    final now = DateTime.now();
    if (_lastBanCheck != null &&
        now.difference(_lastBanCheck!) < _banCheckInterval) {
      return;
    }
    _lastBanCheck = now;

    final uid = await AppStorage.get('uid') as String?;
    if (uid == null || uid.isEmpty) return;

    final result = await BanCheckService.checkBanStatus(uid);
    if (result.isBanned) {
      await BanCheckService.handleBannedUser(
        banReason: result.banReason ?? 'Account banned',
        banUntil: result.banUntil,
      );
    }
  }

  // Returns the root context via the navigator key so deep link service
  // always has a live context even after multiple navigations.
  BuildContext? _getRootContext() => rootNavigatorKey.currentContext;

  void _initDeepLinks() {
    if (_deepLinkInitialized) return;
    _deepLinkInitialized = true;

    // Group invite: private group deep link → show JoinGroupScreen sheet
    setGroupInviteCallback((inviteCode) {
      final ctx = _getRootContext();
      if (ctx == null) return;
      showModalBottomSheet(
        context: ctx,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => JoinGroupScreen(inviteCode: inviteCode),
      );
    });

    // app_links — listens for witalk:// and https://witalk.in/* (cold + warm)
    deepLinkService.init(getContext: () => _getRootContext()!);

    // Notification tap handler — routes all OneSignal notification taps
    notificationService.setNavigationHandler((data) {
      final ctx = _getRootContext();
      if (ctx == null) return;
      handleNotificationNavigation(ctx, data);
    });
  }

  void _checkAndInitUser() {
    final auth = ref.read(authProvider);
    if (auth.status == AuthStatus.authenticated && auth.uid != null) {
      final userNotifier = ref.read(userProvider.notifier);
      userNotifier.loadFromStorage().then((_) => userNotifier.fetchAndCache(auth.uid!));
      // Pre-fetch create-action flags so the sheet never shows a loader.
      ref.read(createActionProvider.notifier).load();
    }
  }

  void _checkAndInitChat() {
    final auth = ref.read(authProvider);
    if (auth.status == AuthStatus.authenticated && auth.uid != null && !_chatInitialized) {
      _chatInitialized = true;
      _initChatSystem(auth.uid!);
      notificationService.setExternalUserId(auth.uid!);
      if (!_locationStartupDone) {
        _locationStartupDone = true;
        _runLocationStartup(auth.uid!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    // Connect Socket.IO, initialize chat provider & run location startup when authenticated
    ref.listen(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && next.uid != null) {
        // Warm up user profile cache whenever we get an authenticated uid
        final wasUnauthenticated = prev?.status != AuthStatus.authenticated;
        if (wasUnauthenticated) {
          final userNotifier = ref.read(userProvider.notifier);
          userNotifier.loadFromStorage().then((_) => userNotifier.fetchAndCache(next.uid!));
          ref.read(createActionProvider.notifier).load();
        }
        if (!_chatInitialized) {
          _chatInitialized = true;
          _initChatSystem(next.uid!);
          notificationService.setExternalUserId(next.uid!);
          if (!_locationStartupDone) {
            _locationStartupDone = true;
            _runLocationStartup(next.uid!);
          }
        }
        // Process any deep link or notification that arrived before login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _getRootContext();
          if (ctx != null) processPendingDeepLinkAfterLogin(ctx);
        });
      } else if (next.status == AuthStatus.unauthenticated) {
        _chatInitialized = false;
        ref.read(userProvider.notifier).clearUser();
        socketService.disconnect();
        messageSyncManager.cleanup();
        notificationService.logout();
        locationService.stopTracking();
        _locationStartupDone = false;
      }
    });

    final overlayStyle = isDark
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MaterialApp.router(
        title: 'WiTalk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
      ),
    );
  }

  /// Wire socket → chatProvider → load initial conversations + groups + channels.
  Future<void> _initChatSystem(String uid) async {
    try {
      // 1. Connect socket (also starts /group-chat and /channel namespace connections)
      final socket = await socketService.connect();

      // 2. Wire all sockets into chatProvider so it receives all events
      ref.read(chatProvider.notifier).init(
        socket,
        uid,
        groupSocket: socketService.groupSocket,
        channelSocket: socketService.channelSocket,
      );

      // 3. Initialize offline sync manager
      final db = ref.read(appDatabaseProvider);
      await messageSyncManager.initialize(socket, uid, db);

      // 4. Load conversations + groups + channels from API (parallel)
      final apiService = chatApiService;
      final results = await Future.wait([
        apiService.getConversations(uid).catchError((_) => <Map<String, dynamic>>[]),
        apiService.getUserGroups(uid).catchError((_) => <Map<String, dynamic>>[]),
        // Channels fetched via the dedicated ChannelApi
        ChannelApi.getMy().then((res) {
          final raw = res.data?['channels'];
          return raw is List
              ? List<Map<String, dynamic>>.from(
                  raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)))
              : <Map<String, dynamic>>[];
        }).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final convs = (results[0] as List<Map<String, dynamic>>)
          .map((e) => ChatConversation.fromJson(e))
          .toList();
      final groups = (results[1] as List<Map<String, dynamic>>)
          .map((e) => ChatConversation.fromJson(e))
          .toList();
      final channels = results[2] as List<Map<String, dynamic>>;

      ref.read(chatProvider.notifier).setConversations(convs);
      ref.read(chatProvider.notifier).setGroups(groups);
      ref.read(chatProvider.notifier).setChannels(channels);

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
    WidgetsBinding.instance.removeObserver(this);
    stopScreenshotListener();
    deepLinkService.dispose();
    locationService.stopTracking();
    super.dispose();
  }
}
