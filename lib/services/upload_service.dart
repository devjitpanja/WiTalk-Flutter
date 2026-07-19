import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

// Canonical upload service — chat screens import this.
// Thin wrapper around the existing api/upload_service.dart logic,
// exposed as an instance so it can be injected/mocked.
class UploadService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<Map<String, dynamic>> uploadFile(File file, String type) async {
    try {
      final token = await _storage.read(key: 'accessToken');
      final uid = await _storage.read(key: 'uid') ?? '';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
        'user_id': uid,
        'type': type,
      });

      final res = await Dio().post(
        AppConfig.filesApiUrl,
        data: formData,
        options: Options(
          headers: {
            'Authorization': token != null ? 'Bearer $token' : '',
          },
        ),
      );

      final data = res.data;
      if (data is Map) {
        final fileData = data['file'] ?? data['data'];
        if (fileData is Map) {
          return Map<String, dynamic>.from(fileData);
        }
        return Map<String, dynamic>.from(data);
      }
      return {'url': null};
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<bool> deleteFile(String fileUrl) async {
    try {
      final token = await _storage.read(key: 'accessToken');
      await Dio().delete(
        AppConfig.filesDeleteUrl,
        data: {'url': fileUrl},
        options: Options(
            headers: {
              'Authorization': token != null ? 'Bearer $token' : ''
            }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
