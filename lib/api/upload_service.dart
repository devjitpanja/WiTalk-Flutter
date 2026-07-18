import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class UploadService {
  static final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> uploadFile(File file, {String field = 'file', String? filename, String? userId}) async {
    try {
      final token = await _storage.read(key: 'accessToken');
      final uid = userId ?? await _storage.read(key: 'uid') ?? '';

      final formData = FormData.fromMap({
        field: await MultipartFile.fromFile(file.path, filename: filename ?? file.path.split('/').last),
        'user_id': uid,
      });

      final res = await Dio().post(
        AppConfig.filesApiUrl,
        data: formData,
        options: Options(headers: {
          'Authorization': token != null ? 'Bearer $token' : '',
        }),
      );

      final fileData = res.data['file'];
      if (fileData is Map) return fileData['url'] as String?;
      return res.data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> uploadProfilePic(File file) =>
      uploadFile(file, field: 'file', filename: 'avatar_${file.path.split('/').last}');

  static Future<String?> uploadChatMedia(File file) {
    final ext = file.path.endsWith('.mp4') ? '.mp4' : '.jpg';
    return uploadFile(file, field: 'file', filename: 'media_${file.path.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '')}$ext');
  }

  static Future<bool> deleteFile(String fileUrl) async {
    try {
      final token = await _storage.read(key: 'accessToken');
      await Dio().delete(
        AppConfig.filesDeleteUrl,
        data: {'url': fileUrl},
        options: Options(headers: {'Authorization': token != null ? 'Bearer $token' : ''}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
