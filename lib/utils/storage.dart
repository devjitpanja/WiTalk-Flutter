import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'logger.dart';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

class AppStorage {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── General key-value ────────────────────────────────────────────────────

  static Future<void> set(String key, dynamic value) async {
    try {
      final prefs = await _getPrefs();
      if (value == null) {
        await prefs.remove(key);
        return;
      }
      final String toStore = value is String ? value : jsonEncode(value);
      await prefs.setString(key, toStore);
      AppLogger.log('Storage: stored $key');
    } catch (e) {
      AppLogger.error('Storage set error', e);
      rethrow;
    }
  }

  static Future<dynamic> get(String key) async {
    try {
      final prefs = await _getPrefs();
      final value = prefs.getString(key);
      if (value == null) return null;
      try {
        return jsonDecode(value);
      } catch (_) {
        return value;
      }
    } catch (e) {
      AppLogger.error('Storage get error', e);
      rethrow;
    }
  }

  static Future<void> remove(String key) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(key);
      AppLogger.log('Storage: removed $key');
    } catch (e) {
      AppLogger.error('Storage remove error', e);
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await _getPrefs();
      await prefs.clear();
      await clearAuthTokens();
      AppLogger.log('Storage: cleared all');
    } catch (e) {
      AppLogger.error('Storage clear error', e);
    }
  }

  static Future<Map<String, dynamic>> getMultiple(List<String> keys) async {
    final prefs = await _getPrefs();
    final result = <String, dynamic>{};
    for (final key in keys) {
      final value = prefs.getString(key);
      if (value != null) {
        try {
          result[key] = jsonDecode(value);
        } catch (_) {
          result[key] = value;
        }
      } else {
        result[key] = null;
      }
    }
    return result;
  }

  static Future<void> setMultiple(List<MapEntry<String, dynamic>> pairs) async {
    final prefs = await _getPrefs();
    for (final entry in pairs) {
      final toStore = entry.value is String ? entry.value as String : jsonEncode(entry.value);
      await prefs.setString(entry.key, toStore);
    }
    AppLogger.log('Storage: stored multiple values');
  }

  static Future<Set<String>> getAllKeys() async {
    final prefs = await _getPrefs();
    return prefs.getKeys();
  }

  static Future<bool> hasKey(String key) async {
    final prefs = await _getPrefs();
    return prefs.containsKey(key);
  }

  // ── Auth tokens (secure storage) ─────────────────────────────────────────

  static Future<bool> setAuthTokens(
    String accessToken,
    String refreshToken, {
    int expiresIn = 900,
    int refreshExpiresIn = 30 * 24 * 60 * 60,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final accessExpiry = now + expiresIn * 1000;
      final refreshExpiry = now + refreshExpiresIn * 1000;

      await Future.wait([
        _secureStorage.write(key: 'accessToken', value: accessToken),
        _secureStorage.write(key: 'refreshToken', value: refreshToken),
        _secureStorage.write(key: 'tokenExpiry', value: accessExpiry.toString()),
        _secureStorage.write(key: 'refreshTokenExpiry', value: refreshExpiry.toString()),
      ]);
      AppLogger.log('Auth tokens stored');
      return true;
    } catch (e) {
      AppLogger.error('setAuthTokens error', e);
      return false;
    }
  }

  static Future<Map<String, dynamic>> getAuthTokens() async {
    try {
      final results = await Future.wait([
        _secureStorage.read(key: 'accessToken'),
        _secureStorage.read(key: 'refreshToken'),
        _secureStorage.read(key: 'tokenExpiry'),
      ]);
      return {
        'accessToken': results[0],
        'refreshToken': results[1],
        'tokenExpiry': results[2] != null ? int.tryParse(results[2]!) : null,
      };
    } catch (e) {
      AppLogger.error('getAuthTokens error', e);
      return {'accessToken': null, 'refreshToken': null, 'tokenExpiry': null};
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: 'accessToken');
    } catch (e) {
      AppLogger.error('getAccessToken error', e);
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: 'refreshToken');
    } catch (e) {
      AppLogger.error('getRefreshToken error', e);
      return null;
    }
  }

  static Future<bool> isAccessTokenExpired() async {
    try {
      final expStr = await _secureStorage.read(key: 'tokenExpiry');
      if (expStr == null) return true;
      final expiry = int.tryParse(expStr);
      if (expiry == null) return true;
      // Expire 1 minute early
      return DateTime.now().millisecondsSinceEpoch >= expiry - 60000;
    } catch (e) {
      AppLogger.error('isAccessTokenExpired error', e);
      return true;
    }
  }

  static Future<bool> isRefreshTokenExpired() async {
    try {
      final expStr = await _secureStorage.read(key: 'refreshTokenExpiry');
      if (expStr == null) return true;
      final expiry = int.tryParse(expStr);
      if (expiry == null) return true;
      return DateTime.now().millisecondsSinceEpoch >= expiry;
    } catch (e) {
      AppLogger.error('isRefreshTokenExpired error', e);
      return true;
    }
  }

  static Future<bool> clearAuthTokens() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: 'accessToken'),
        _secureStorage.delete(key: 'refreshToken'),
        _secureStorage.delete(key: 'tokenExpiry'),
        _secureStorage.delete(key: 'refreshTokenExpiry'),
      ]);
      AppLogger.log('Auth tokens cleared');
      return true;
    } catch (e) {
      AppLogger.error('clearAuthTokens error', e);
      return false;
    }
  }

  static Future<bool> updateAccessToken(String accessToken, {int expiresIn = 900}) async {
    try {
      final expiry = DateTime.now().millisecondsSinceEpoch + expiresIn * 1000;
      await Future.wait([
        _secureStorage.write(key: 'accessToken', value: accessToken),
        _secureStorage.write(key: 'tokenExpiry', value: expiry.toString()),
      ]);
      AppLogger.log('Access token updated');
      return true;
    } catch (e) {
      AppLogger.error('updateAccessToken error', e);
      return false;
    }
  }

  static Future<bool> hasAuthTokens() async {
    try {
      final access = await _secureStorage.read(key: 'accessToken');
      final refresh = await _secureStorage.read(key: 'refreshToken');
      return access != null && access.isNotEmpty && refresh != null && refresh.isNotEmpty;
    } catch (e) {
      AppLogger.error('hasAuthTokens error', e);
      return false;
    }
  }

  // ── Voice call sessions ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> addVoiceCallSession(
    Map<String, dynamic> sessionData,
  ) async {
    try {
      final existing = (await get('voiceCallSessions')) ?? [];
      final sessions = List<Map<String, dynamic>>.from(
        existing is List ? existing : [],
      );
      sessions.add({
        ...sessionData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'id': 'session_${DateTime.now().millisecondsSinceEpoch}',
      });
      final limited = sessions.length > 50 ? sessions.sublist(sessions.length - 50) : sessions;
      await set('voiceCallSessions', limited);
      return limited;
    } catch (e) {
      AppLogger.error('addVoiceCallSession error', e);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getVoiceCallSessions() async {
    try {
      final sessions = await get('voiceCallSessions');
      if (sessions == null) return [];
      if (sessions is List) return List<Map<String, dynamic>>.from(sessions);
      await set('voiceCallSessions', []);
      return [];
    } catch (e) {
      AppLogger.error('getVoiceCallSessions error', e);
      return [];
    }
  }
}
