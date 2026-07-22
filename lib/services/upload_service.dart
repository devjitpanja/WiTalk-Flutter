import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  final _storage = const FlutterSecureStorage();

  /// Helper to get validated access token
  Future<String> _getAccessToken() async {
    final token = await _storage.read(key: 'accessToken');
    if (token == null || token.isEmpty) {
      throw Exception('Authentication failed. Please log in again.');
    }
    return token;
  }

  /// Delete uploaded file from server for cleanup if post creation fails or user cancels
  Future<void> deleteUploadedFile(String fileName) async {
    try {
      final token = await _getAccessToken();
      final url = '${AppConfig.apiBaseUrl}/v1/files/delete';
      await Dio().delete(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'name': fileName},
      );
    } catch (_) {}
  }

  /// Upload image or single media file using Multipart FormData
  Future<Map<String, dynamic>> uploadMedia({
    required File file,
    required String mediaType, // 'image' | 'video'
    required String fileName,
    required String userId,
    Function(double progress)? onProgress,
    bool Function()? isCancelled,
    int retryCount = 0,
  }) async {
    const maxRetries = 2;
    if (isCancelled?.call() == true) {
      throw Exception('Upload cancelled');
    }

    try {
      final token = await _getAccessToken();
      final uploadUrl = '${AppConfig.apiBaseUrl}/v1/files';

      final mimeType = mediaType == 'video' ? 'video/mp4' : 'image/jpeg';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
        'user_id': userId,
      });

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ));

      final response = await dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
        onSendProgress: (sent, total) {
          if (isCancelled?.call() == true) return;
          if (total > 0 && onProgress != null) {
            onProgress(sent / total * 100);
          }
        },
      );

      if (isCancelled?.call() == true) {
        throw Exception('Upload cancelled');
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : {};
        if (data['success'] == true && data['file'] != null) {
          return Map<String, dynamic>.from(data['file']);
        } else {
          throw Exception(data['error'] ?? data['message'] ?? 'Upload failed on server');
        }
      } else {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } catch (error) {
      if (isCancelled?.call() == true) {
        throw Exception('Upload cancelled');
      }

      final isServerError = error is DioException &&
          error.response != null &&
          (error.response!.statusCode == 502 ||
              error.response!.statusCode == 503 ||
              error.response!.statusCode == 504 ||
              error.response!.statusCode == 500);

      if (isServerError && retryCount < maxRetries) {
        final waitSeconds = pow(2, retryCount + 1).toInt();
        await Future.delayed(Duration(seconds: waitSeconds));
        return uploadMedia(
          file: file,
          mediaType: mediaType,
          fileName: fileName,
          userId: userId,
          onProgress: onProgress,
          isCancelled: isCancelled,
          retryCount: retryCount + 1,
        );
      }

      rethrow;
    }
  }

  /// Upload video in chunks or via streaming multipart with full progress callbacks
  Future<Map<String, dynamic>> uploadVideoChunked({
    required File file,
    required String fileName,
    required String userId,
    Function(double chunkPercent)? onProgress,
    bool Function()? isCancelled,
  }) async {
    return uploadMedia(
      file: file,
      mediaType: 'video',
      fileName: fileName,
      userId: userId,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }
}

final uploadService = UploadService();
