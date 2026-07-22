import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'storage.dart';
import 'logger.dart';

final _dio = Dio();

Future<Map<String, dynamic>> testBackendConnectivity() async {
  final results = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'tests': <Map<String, dynamic>>[],
  };
  final tests = results['tests'] as List<Map<String, dynamic>>;

  // Test 1: Health check
  AppLogger.log('[DIAG] Testing health check endpoint...');
  try {
    final sw = Stopwatch()..start();
    final response = await _dio.get(
      '${AppConfig.apiBaseUrl}/health',
      options: Options(receiveTimeout: const Duration(seconds: 5)),
    );
    sw.stop();
    tests.add({
      'name': 'Health Check',
      'success': true,
      'duration': '${sw.elapsedMilliseconds}ms',
      'status': response.statusCode,
      'message': 'Backend server is reachable',
    });
    AppLogger.log('[DIAG] Health check passed (${sw.elapsedMilliseconds}ms)');
  } catch (e) {
    tests.add({'name': 'Health Check', 'success': false, 'error': e.toString(), 'message': 'Cannot reach backend server'});
    AppLogger.error('[DIAG] Health check failed', e);
  }

  // Test 2: Check stored tokens
  final userId = await AppStorage.get('uid') as String?;
  if (userId != null) {
    AppLogger.log('[DIAG] Checking stored authentication tokens...');
    try {
      final tokens = await AppStorage.getAuthTokens();
      final isExpired = await AppStorage.isAccessTokenExpired();
      tests.add({
        'name': 'Stored Tokens',
        'success': tokens['accessToken'] != null && tokens['refreshToken'] != null,
        'hasAccessToken': tokens['accessToken'] != null,
        'hasRefreshToken': tokens['refreshToken'] != null,
        'isAccessTokenExpired': isExpired,
        'message': tokens['accessToken'] != null ? 'Tokens found in storage' : 'Missing tokens',
      });
    } catch (e) {
      tests.add({'name': 'Stored Tokens', 'success': false, 'error': e.toString()});
    }

    // Test 3: Authenticated endpoint
    AppLogger.log('[DIAG] Testing authenticated endpoint...');
    final accessToken = await AppStorage.getAccessToken();
    if (accessToken == null) {
      tests.add({'name': 'Authenticated Request', 'success': false, 'message': 'No access token found'});
    } else {
      try {
        final sw = Stopwatch()..start();
        final response = await _dio.get(
          '${AppConfig.apiBaseUrl}/v1/user/$userId',
          options: Options(
            headers: {'Authorization': 'Bearer $accessToken'},
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        sw.stop();
        tests.add({
          'name': 'Authenticated Request',
          'success': true,
          'duration': '${sw.elapsedMilliseconds}ms',
          'status': response.statusCode,
        });
      } catch (e) {
        tests.add({'name': 'Authenticated Request', 'success': false, 'error': e.toString()});
      }
    }

    // Test 4: Token refresh (only if expired)
    final isExpired = await AppStorage.isAccessTokenExpired();
    if (isExpired) {
      final refreshToken = await AppStorage.getRefreshToken();
      if (refreshToken == null) {
        tests.add({'name': 'Token Refresh', 'success': false, 'message': 'No refresh token available'});
      } else {
        try {
          final sw = Stopwatch()..start();
          final response = await _dio.post(
            '${AppConfig.apiBaseUrl}/v1/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(receiveTimeout: const Duration(seconds: 5)),
          );
          sw.stop();
          tests.add({'name': 'Token Refresh', 'success': true, 'duration': '${sw.elapsedMilliseconds}ms', 'status': response.statusCode});
        } catch (e) {
          tests.add({'name': 'Token Refresh', 'success': false, 'error': e.toString()});
        }
      }
    } else {
      tests.add({'name': 'Token Refresh', 'success': true, 'skipped': true, 'message': 'Access token still valid'});
    }
  }

  final passed = tests.where((t) => t['success'] == true).length;
  results['summary'] = {
    'passed': passed,
    'failed': tests.length - passed,
    'total': tests.length,
    'success': passed == tests.length,
  };
  AppLogger.log('[DIAG] Summary', results['summary']);
  return results;
}

Future<bool> quickConnectivityCheck() async {
  const maxRetries = 1;
  const retryDelay = Duration(milliseconds: 300);

  for (var attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      AppLogger.log('[DIAG] Quick connectivity check attempt ${attempt + 1}/${maxRetries + 1}');
      await _dio.get(
        '${AppConfig.apiBaseUrl}/health',
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      AppLogger.log('[DIAG] Quick connectivity check successful');
      return true;
    } catch (e) {
      AppLogger.error('[DIAG] Quick connectivity check failed', e);
      if (attempt < maxRetries) await Future.delayed(retryDelay);
    }
  }
  return false;
}

Future<Map<String, dynamic>> checkTokenStatus() async {
  try {
    final tokens = await AppStorage.getAuthTokens();
    final isExpired = await AppStorage.isAccessTokenExpired();
    final expiry = tokens['tokenExpiry'] as int?;
    return {
      'hasTokens': tokens['accessToken'] != null && tokens['refreshToken'] != null,
      'isExpired': isExpired,
      'expiry': expiry != null ? DateTime.fromMillisecondsSinceEpoch(expiry).toIso8601String() : null,
      'timeUntilExpiry': expiry != null
          ? (expiry - DateTime.now().millisecondsSinceEpoch).clamp(0, double.maxFinite.toInt())
          : null,
    };
  } catch (e) {
    AppLogger.error('[DIAG] Token status check failed', e);
    return {'hasTokens': false, 'isExpired': true, 'error': e.toString()};
  }
}
