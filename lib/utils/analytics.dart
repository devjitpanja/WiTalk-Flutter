import 'package:firebase_analytics/firebase_analytics.dart';
import 'logger.dart';

class Analytics {
  static FirebaseAnalytics get _instance => FirebaseAnalytics.instance;

  static Future<void> logEvent(String eventName, [Map<String, Object>? params]) async {
    try {
      await _instance.logEvent(name: eventName, parameters: params);
      AppLogger.log('Analytics Event: $eventName', params);
    } catch (e) {
      AppLogger.error('Analytics logEvent error', e);
    }
  }

  static Future<void> logScreenView(String screenName, [String? screenClass]) async {
    try {
      await _instance.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      AppLogger.log('Analytics Screen View: $screenName');
    } catch (e) {
      AppLogger.error('Analytics logScreenView error', e);
    }
  }

  static Future<void> logLogin(String method) async {
    try {
      await _instance.logLogin(loginMethod: method);
      AppLogger.log('Analytics Login: $method');
    } catch (e) {
      AppLogger.error('Analytics logLogin error', e);
    }
  }

  static Future<void> logSignUp(String method) async {
    try {
      await _instance.logSignUp(signUpMethod: method);
      AppLogger.log('Analytics Sign Up: $method');
    } catch (e) {
      AppLogger.error('Analytics logSignUp error', e);
    }
  }

  static Future<void> logShare(String contentType, String itemId, String method) async {
    try {
      await _instance.logShare(
        contentType: contentType,
        itemId: itemId,
        method: method,
      );
      AppLogger.log('Analytics Share: $contentType - $itemId');
    } catch (e) {
      AppLogger.error('Analytics logShare error', e);
    }
  }

  static Future<void> logSearch(String searchTerm) async {
    try {
      await _instance.logSearch(searchTerm: searchTerm);
      AppLogger.log('Analytics Search: $searchTerm');
    } catch (e) {
      AppLogger.error('Analytics logSearch error', e);
    }
  }

  static Future<void> setUserId(String userId) async {
    try {
      await _instance.setUserId(id: userId);
      AppLogger.log('Analytics User ID Set: $userId');
    } catch (e) {
      AppLogger.error('Analytics setUserId error', e);
    }
  }

  static Future<void> setUserProperty(String name, String value) async {
    try {
      await _instance.setUserProperty(name: name, value: value);
      AppLogger.log('Analytics User Property: $name = $value');
    } catch (e) {
      AppLogger.error('Analytics setUserProperty error', e);
    }
  }

  static Future<void> setUserProperties(Map<String, String> properties) async {
    try {
      await Future.wait(
        properties.entries.map((e) => _instance.setUserProperty(name: e.key, value: e.value)),
      );
      AppLogger.log('Analytics User Properties Set', properties);
    } catch (e) {
      AppLogger.error('Analytics setUserProperties error', e);
    }
  }

  static Future<void> logPostCreated(String postType) async {
    await logEvent('post_created', {'post_type': postType});
  }

  static Future<void> logPostInteraction(String interactionType, String postId) async {
    await logEvent('post_interaction', {'interaction_type': interactionType, 'post_id': postId});
  }

  static Future<void> logMessageSent(String chatType) async {
    await logEvent('message_sent', {'chat_type': chatType});
  }

  static Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _instance.setAnalyticsCollectionEnabled(enabled);
      AppLogger.log('Analytics Collection ${enabled ? 'Enabled' : 'Disabled'}');
    } catch (e) {
      AppLogger.error('Analytics setAnalyticsCollectionEnabled error', e);
    }
  }

  static Future<void> resetAnalyticsData() async {
    try {
      await _instance.resetAnalyticsData();
      AppLogger.log('Analytics Data Reset');
    } catch (e) {
      AppLogger.error('Analytics resetAnalyticsData error', e);
    }
  }
}
