import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

const String _baseUrl = AppConfig.apiBaseUrl;

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  DioClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'x-app-version': '200',
        'x-platform': 'android',
      },
    ));

    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true, error: true));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: 'access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;
      final res = await Dio().post('$_baseUrl/v1/auth/refresh', data: {'refreshToken': refreshToken});
      final tokens = res.data['data'];
      await _storage.write(key: 'access_token', value: tokens['accessToken']);
      await _storage.write(key: 'refresh_token', value: tokens['refreshToken']);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final dioClient = DioClient().dio;
