import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import 'storage.dart';
import 'logger.dart';

const _chunkSizeBytes = 2 * 1024 * 1024; // 2 MB
const _maxChunkRetries = 3;
const _retryBaseDelayMs = 1500;

String get _chunkedBaseUrl =>
    '${AppConfig.filesApiUrl.replaceAll(RegExp(r'/single$'), '')}/chunked';

final _dio = Dio();

/// Resolve a file URI/path to an absolute filesystem path.
/// On Android, content:// URIs are copied to a temp file.
/// Returns {path, isTemp}.
Future<({String path, bool isTemp})> resolveToFilePath(String uri) async {
  if (!uri.contains('://')) return (path: uri, isTemp: false);

  if (uri.startsWith('file://')) return (path: uri.substring(7), isTemp: false);

  if (Platform.isAndroid && uri.startsWith('content://')) {
    final cacheDir = await getTemporaryDirectory();
    final destPath = '${cacheDir.path}/witalk_cp_${DateTime.now().millisecondsSinceEpoch}.mp4';
    // Use Android ContentResolver via platform channel (not yet bridged).
    // Fallback: try treating as file path — will fail for true content:// URIs.
    throw UnsupportedError(
      'content:// URIs require a platform channel bridge.\n'
      'Wire up a MethodChannel in MainActivity.kt that calls\n'
      'ContentResolver.openInputStream and writes to $destPath.',
    );
  }

  throw UnsupportedError('Unsupported URI scheme: ${uri.substring(0, uri.length.clamp(0, 40))}');
}

Future<void> _sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

/// Upload a single chunk with retry + exponential back-off.
Future<Map<String, dynamic>> _uploadChunkWithRetry(
  String uploadId,
  int chunkIndex,
  String slicePath, {
  int attempt = 1,
}) async {
  try {
    final token = await AppStorage.getAccessToken();
    final formData = FormData.fromMap({
      'uploadId': uploadId,
      'chunkIndex': chunkIndex.toString(),
      'chunk': await MultipartFile.fromFile(
        slicePath,
        filename: 'chunk_$chunkIndex',
        contentType: DioMediaType('application', 'octet-stream'),
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '$_chunkedBaseUrl/chunk',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Chunk rejected by server');
    }
    return response.data!;
  } catch (e) {
    if (attempt >= _maxChunkRetries) rethrow;
    await _sleep(_retryBaseDelayMs * attempt);
    return _uploadChunkWithRetry(uploadId, chunkIndex, slicePath, attempt: attempt + 1);
  }
}

/// Upload a video file in 2 MB chunks to the FileUploader service.
///
/// [uri] — file path or file:// URI
/// [fileName] — target filename on the server
/// [userId] — authenticated user ID
/// [onProgress] — callback (0–100)
/// [isCancelled] — () => bool, checked per chunk
///
/// Returns the server's file object: {filename, url, type, thumbnail, compression}
Future<Map<String, dynamic>> uploadVideoChunked({
  required String uri,
  required String fileName,
  required String userId,
  void Function(int percent)? onProgress,
  bool Function()? isCancelled,
}) async {
  String? filePath;
  bool isTemp = false;
  final cacheDir = await getTemporaryDirectory();
  final slicePrefix = '${cacheDir.path}/witalk_slice_${DateTime.now().millisecondsSinceEpoch}';

  try {
    final resolved = await resolveToFilePath(uri);
    filePath = resolved.path;
    isTemp = resolved.isTemp;

    final file = File(filePath);
    final fileSize = file.lengthSync();
    if (fileSize == 0) throw Exception('Video file is empty or unreadable');

    final totalChunks = (fileSize / _chunkSizeBytes).ceil();

    AppLogger.log('[ChunkedUpload] Start: $fileName, ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB, $totalChunks chunks');

    // Start upload session
    final token = await AppStorage.getAccessToken();
    final startResp = await _dio.post<Map<String, dynamic>>(
      '$_chunkedBaseUrl/start',
      data: {
        'fileName': fileName,
        'fileSize': fileSize,
        'totalChunks': totalChunks,
        'userId': userId,
        'fileType': 'videos',
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (startResp.data?['success'] != true) {
      throw Exception(startResp.data?['error'] ?? 'Start session failed');
    }
    final uploadId = startResp.data!['uploadId'] as String;

    // Upload each chunk
    final fileBytes = file.readAsBytesSync();
    for (var i = 0; i < totalChunks; i++) {
      if (isCancelled?.call() == true) throw Exception('Upload cancelled');

      final start = i * _chunkSizeBytes;
      final end = (start + _chunkSizeBytes).clamp(0, fileSize);
      final slicePath = '${slicePrefix}_$i';

      // Write chunk to temp file
      final sliceFile = File(slicePath);
      await sliceFile.writeAsBytes(fileBytes.sublist(start, end));

      try {
        await _uploadChunkWithRetry(uploadId, i, slicePath);
      } finally {
        try { sliceFile.deleteSync(); } catch (_) {}
      }

      onProgress?.call(((i + 1) / totalChunks * 100).round());
    }

    // Finalize
    if (isCancelled?.call() == true) throw Exception('Upload cancelled');

    final finalToken = await AppStorage.getAccessToken();
    final finalResp = await _dio.post<Map<String, dynamic>>(
      '$_chunkedBaseUrl/finalize',
      data: {'uploadId': uploadId},
      options: Options(headers: {'Authorization': 'Bearer $finalToken'}),
    );

    if (finalResp.data?['success'] != true) {
      throw Exception(finalResp.data?['error'] ?? 'Finalize failed');
    }

    AppLogger.log('[ChunkedUpload] Done: $fileName');
    return finalResp.data!['file'] as Map<String, dynamic>;
  } catch (e) {
    AppLogger.error('[ChunkedUpload] Error', e);
    rethrow;
  } finally {
    if (isTemp && filePath != null) {
      try { File(filePath).deleteSync(); } catch (_) {}
    }
    // Clean up any leftover slice files
    final cacheFiles = cacheDir.listSync();
    for (final f in cacheFiles) {
      if (f is File && f.path.contains('witalk_slice_')) {
        try { f.deleteSync(); } catch (_) {}
      }
    }
  }
}
