import 'dart:io';
import 'package:dio/dio.dart';
import 'app_endpoints.dart';
import 'dio_client.dart';

class UploadService {
  static Future<String?> uploadFile(File file, {String field = 'file', String? filename}) async {
    try {
      final formData = FormData.fromMap({
        field: await MultipartFile.fromFile(file.path, filename: filename ?? file.path.split('/').last),
      });
      final res = await dioClient.post(AppEndpoints.uploadSingle, data: formData);
      return res.data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> uploadProfilePic(File file) =>
      uploadFile(file, field: 'file', filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');

  static Future<String?> uploadChatMedia(File file) =>
      uploadFile(file, field: 'file', filename: 'media_${DateTime.now().millisecondsSinceEpoch}${file.path.endsWith('.mp4') ? '.mp4' : '.jpg'}');
}
