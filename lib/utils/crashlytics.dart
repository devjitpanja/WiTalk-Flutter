import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'logger.dart';

class Crashlytics {
  static FirebaseCrashlytics get _instance => FirebaseCrashlytics.instance;

  static Future<void> initialize() async {
    try {
      await _instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      AppLogger.log('Crashlytics initialized');
    } catch (e) {
      AppLogger.error('Crashlytics initialization error', e);
    }
  }

  static void recordError(Object error, StackTrace? stack, {String context = ''}) {
    try {
      if (context.isNotEmpty) _instance.log('Error context: $context');
      _instance.recordError(error, stack, fatal: false);
      AppLogger.log('Crashlytics: Error recorded', error.toString());
    } catch (e) {
      AppLogger.error('Crashlytics recordError failed', e);
    }
  }

  static void log(String message) {
    try {
      _instance.log(message);
      AppLogger.log('Crashlytics Log: $message');
    } catch (e) {
      AppLogger.error('Crashlytics log error', e);
    }
  }

  static Future<void> setUserId(String userId) async {
    try {
      await _instance.setUserIdentifier(userId);
      AppLogger.log('Crashlytics User ID Set: $userId');
    } catch (e) {
      AppLogger.error('Crashlytics setUserId error', e);
    }
  }

  static Future<void> setAttribute(String key, String value) async {
    try {
      await _instance.setCustomKey(key, value);
      AppLogger.log('Crashlytics Attribute: $key = $value');
    } catch (e) {
      AppLogger.error('Crashlytics setAttribute error', e);
    }
  }

  static Future<void> setAttributes(Map<String, String> attributes) async {
    try {
      await Future.wait(
        attributes.entries.map((e) => _instance.setCustomKey(e.key, e.value)),
      );
      AppLogger.log('Crashlytics Attributes Set', attributes);
    } catch (e) {
      AppLogger.error('Crashlytics setAttributes error', e);
    }
  }

  static void recordJSException(Object error, StackTrace? stack, {bool isFatal = false}) {
    try {
      _instance.log('Flutter Exception - Fatal: $isFatal');
      _instance.recordError(error, stack, fatal: isFatal);
      AppLogger.log('Crashlytics: Exception recorded');
    } catch (e) {
      AppLogger.error('Crashlytics recordJSException failed', e);
    }
  }

  static void logNetworkError(String url, int statusCode, String errorMessage) {
    try {
      log('Network Error: $statusCode - $url');
      setAttribute('last_network_error_url', url);
      setAttribute('last_network_error_code', statusCode.toString());
      recordError(
        Exception('Network Error: $statusCode - $errorMessage'),
        StackTrace.current,
        context: 'URL: $url',
      );
    } catch (e) {
      AppLogger.error('Crashlytics logNetworkError failed', e);
    }
  }

  static void logAuthError(String authMethod, String errorMessage) {
    try {
      log('Auth Error: $authMethod - $errorMessage');
      setAttribute('last_auth_error_method', authMethod);
      recordError(
        Exception('Auth Error: $errorMessage'),
        StackTrace.current,
        context: 'Method: $authMethod',
      );
    } catch (e) {
      AppLogger.error('Crashlytics logAuthError failed', e);
    }
  }

  static Future<void> clearUserData() async {
    try {
      await setUserId('');
      await setAttributes({
        'user_logged_in': 'false',
        'last_logout': DateTime.now().toIso8601String(),
      });
      AppLogger.log('Crashlytics: User data cleared');
    } catch (e) {
      AppLogger.error('Crashlytics clearUserData error', e);
    }
  }

  static Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    try {
      await _instance.setCrashlyticsCollectionEnabled(enabled);
      AppLogger.log('Crashlytics Collection ${enabled ? 'Enabled' : 'Disabled'}');
    } catch (e) {
      AppLogger.error('Crashlytics setCrashlyticsCollectionEnabled error', e);
    }
  }
}
