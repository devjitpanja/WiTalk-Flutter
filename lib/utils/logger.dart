import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// ignore_for_file: non_constant_identifier_names

class AppLoggerInstance {
  final String _scope;
  final String _prefix;

  AppLoggerInstance(this._scope) : _prefix = '[$_scope]';

  void log(String message, [Object? data]) {
    if (kReleaseMode) return;
    debugPrint('$_prefix $message${data != null ? ' $data' : ''}');
  }

  void info(String message, [Object? data]) {
    if (kReleaseMode) return;
    debugPrint('$_prefix $message${data != null ? ' $data' : ''}');
  }

  void warn(String message, [Object? data]) {
    if (kReleaseMode) return;
    debugPrint('⚠️ $_prefix $message${data != null ? ' $data' : ''}');
  }

  void error(String message, [Object? data]) {
    debugPrint('❌ $_prefix $message${data != null ? ' $data' : ''}');
    if (!kDebugMode) {
      try {
        FirebaseCrashlytics.instance.log('$_prefix $message');
      } catch (_) {}
    }
  }

  void debug(String message, [Object? data]) {
    if (kReleaseMode) return;
    debugPrint('$_prefix [DEBUG] $message${data != null ? ' $data' : ''}');
  }

  void separator([String message = '']) {
    if (kReleaseMode) return;
    const line = '═══════════════════════════════════════════════════════════════';
    debugPrint(line);
    if (message.isNotEmpty) {
      debugPrint('$_prefix $message');
      debugPrint(line);
    }
  }

  void emoji(String emoji, String message, [Object? data]) {
    if (kReleaseMode) return;
    debugPrint('$emoji $_prefix $message${data != null ? ' $data' : ''}');
  }

  AppLoggerInstance createChild(String childScope) => AppLoggerInstance('$_scope:$childScope');
}

class LoggerFactory {
  static AppLoggerInstance create(String scope) => AppLoggerInstance(scope);
}

// Pre-created scoped loggers — PascalCase matches usage across the codebase
final AppLogger = LoggerFactory.create('App');
final ChatLogger = LoggerFactory.create('Chat');
final NotificationLogger = LoggerFactory.create('Notification');
final NavigationLogger = LoggerFactory.create('Navigation');
final APILogger = LoggerFactory.create('API');
final WebRTCLogger = LoggerFactory.create('WebRTC');
final LocationLogger = LoggerFactory.create('Location');
final FCMLogger = LoggerFactory.create('FCM');
final DeepLinkLogger = LoggerFactory.create('DeepLink');
final BackHandlerLogger = LoggerFactory.create('BackHandler');
