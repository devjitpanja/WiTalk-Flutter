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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase — google-services.json is in android/app/
  await Firebase.initializeApp();

  // Push notifications (OneSignal)
  await notificationService.initialize();

  runApp(const ProviderScope(child: WiTalkApp()));
}

class WiTalkApp extends ConsumerWidget {
  const WiTalkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);

    // Connect Socket.IO when authenticated
    ref.listen(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && prev?.status != AuthStatus.authenticated) {
        socketService.connect();
        final uid = next.uid;
        if (uid != null) notificationService.setExternalUserId(uid);
      } else if (next.status == AuthStatus.unauthenticated) {
        socketService.disconnect();
        notificationService.logout();
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
}
