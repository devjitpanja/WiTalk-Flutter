import 'package:dio/dio.dart';
import 'logger.dart';

const _findipApiToken = '160d9f7e3e634f5d896ec75b000c68d9';
final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

Future<String?> getPublicIP() async {
  try {
    final response = await _dio.get('https://api.ipify.org?format=json');
    final ip = response.data['ip'] as String?;
    AppLogger.log('[IP Detection] Public IP: $ip');
    return ip;
  } catch (e) {
    AppLogger.error('[IP Detection] Error getting public IP', e);
    return null;
  }
}

Future<Map<String, String?>?> getLocationFromIP(String ipAddress) async {
  try {
    final url = 'https://api.findip.net/$ipAddress/?token=$_findipApiToken';
    final response = await _dio.get(url);
    final data = response.data as Map<String, dynamic>?;

    if (data?['country'] == null) {
      AppLogger.warn('[Location] Invalid response format');
      return null;
    }

    final countryCode = data!['country']['iso_code'] as String? ?? '';
    final country = (data['country']['names'] as Map?)?['en'] as String? ?? '';
    final city = (data['city']?['names'] as Map?)?['en'] as String? ?? '';
    final subdivisions = data['subdivisions'] as List?;
    final state = subdivisions != null && subdivisions.isNotEmpty
        ? ((subdivisions[0]['names'] as Map?)?['en'] as String? ?? '')
        : '';

    AppLogger.log('[Location] Extracted', {'country': country, 'countryCode': countryCode, 'city': city, 'state': state});

    return {
      'country': country,
      'countryCode': countryCode,
      'city': city,
      'state': state,
    };
  } catch (e) {
    AppLogger.error('[Location] Error fetching location', e);
    return null;
  }
}

Future<Map<String, String?>?> getUserCountryFromIP([String? preloadedIp]) async {
  try {
    final ip = preloadedIp ?? await getPublicIP();
    if (ip == null) {
      AppLogger.error('[getUserCountryFromIP] Failed to get IP address');
      return null;
    }
    return await getLocationFromIP(ip);
  } catch (e) {
    AppLogger.error('[getUserCountryFromIP] Error', e);
    return null;
  }
}
