import 'dio_client.dart';

class GraphQLService {
  static final GraphQLService _instance = GraphQLService._internal();
  factory GraphQLService() => _instance;
  GraphQLService._internal();

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

  /// Refresh access token using centralized DioClient refresh mechanism
  Future<bool> refreshToken() async {
    final result = await performTokenRefresh();
    return result.success;
  }
}

final graphQLService = GraphQLService();
