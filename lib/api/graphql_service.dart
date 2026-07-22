import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dio_client.dart';
import '../config/app_config.dart';

class GraphQLService {
  static final GraphQLService _instance = GraphQLService._internal();
  factory GraphQLService() => _instance;
  GraphQLService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isRefreshing = false;

  /// Execute GraphQL query or mutation with automatic token refresh on auth errors.
  Future<Map<String, dynamic>> query({
    required String query,
    Map<String, dynamic>? variables,
    int maxRetries = 1,
  }) async {
    int attempts = 0;

    while (attempts <= maxRetries) {
      try {
        final res = await dioClient.post(
          '/graphql',
          data: {
            'query': query,
            if (variables != null) 'variables': variables,
          },
        );

        final data = res.data as Map<String, dynamic>?;
        if (data == null) {
          throw Exception('Empty response from GraphQL server');
        }

        final errors = data['errors'] as List?;
        if (errors != null && errors.isNotEmpty) {
          final isAuthError = errors.any((err) {
            final msg = err['message']?.toString().toLowerCase() ?? '';
            final code = err['extensions']?['code']?.toString() ?? '';
            return msg.contains('unauthorized') ||
                msg.contains('token_expired') ||
                msg.contains('token expired') ||
                code == 'UNAUTHENTICATED' ||
                code == 'TOKEN_EXPIRED';
          });

          if (isAuthError && attempts < maxRetries) {
            attempts++;
            final refreshed = await refreshToken();
            if (refreshed) {
              continue; // Retry query with new token
            }
          }

          throw Exception(errors.first['message']?.toString() ?? 'GraphQL Error');
        }

        return (data['data'] as Map<String, dynamic>?) ?? {};
      } catch (e) {
        if (attempts >= maxRetries) rethrow;
        attempts++;
      }
    }

    throw Exception('GraphQL query failed after retries');
  }

  /// Manually refresh access token if needed
  Future<bool> refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refreshToken = await _storage.read(key: 'refreshToken');
      if (refreshToken != null) {
        final res = await Dio().post(
          '${AppConfig.apiBaseUrl}/v1/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        final data = res.data['data'];
        if (data != null && data['accessToken'] != null) {
          await _storage.write(key: 'accessToken', value: data['accessToken'] as String);
          if (data['refreshToken'] != null) {
            await _storage.write(key: 'refreshToken', value: data['refreshToken'] as String);
          }
          _isRefreshing = false;
          return true;
        }
      }

      final uid = await _storage.read(key: 'uid');
      if (uid != null) {
        final res = await Dio().post(
          '${AppConfig.apiBaseUrl}/v1/auth/generate-tokens',
          data: {'userId': uid},
        );
        final data = res.data['data'];
        if (data != null && data['accessToken'] != null) {
          await _storage.write(key: 'accessToken', value: data['accessToken'] as String);
          if (data['refreshToken'] != null) {
            await _storage.write(key: 'refreshToken', value: data['refreshToken'] as String);
          }
          _isRefreshing = false;
          return true;
        }
      }
    } catch (_) {}
    _isRefreshing = false;
    return false;
  }
}

final graphQLService = GraphQLService();
