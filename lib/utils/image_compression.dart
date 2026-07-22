import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'logger.dart';

const _maxFileSizeBytes = 2 * 1024 * 1024; // 2 MB
const _minQuality = 10;
const _qualityStep = 10;
const _maxAttempts = 10;

Future<int> _getFileSize(String path) async {
  final file = File(path);
  return file.existsSync() ? file.lengthSync() : 0;
}

/// Iteratively compress an image until it is under [targetSizeBytes] (default 2 MB).
/// Returns a map with {uri, size, quality, originalSize, compressionRatio, isUnderTargetSize}.
Future<Map<String, dynamic>> compressToSize(
  String uri, {
  int targetSizeBytes = _maxFileSizeBytes,
}) async {
  try {
    AppLogger.log('Starting compression for: $uri');
    final originalSize = await _getFileSize(uri);
    AppLogger.log('Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');

    if (originalSize <= targetSizeBytes) {
      AppLogger.log('Image already under target size');
      return {
        'uri': uri,
        'size': originalSize,
        'quality': 100,
        'originalSize': originalSize,
        'compressionRatio': 0.0,
        'isUnderTargetSize': true,
      };
    }

    Map<String, dynamic>? bestResult;
    var currentQuality = 90;
    var attempts = 0;

    while (currentQuality >= _minQuality && attempts < _maxAttempts) {
      attempts++;
      AppLogger.log('Attempt $attempts: quality $currentQuality%');

      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: uri,
          compressQuality: currentQuality,
          compressFormat: ImageCompressFormat.jpg,
        );

        if (croppedFile == null) break;

        final size = await _getFileSize(croppedFile.path);
        AppLogger.log('Compressed size: ${(size / 1024 / 1024).toStringAsFixed(2)}MB');

        bestResult = {'uri': croppedFile.path, 'size': size, 'quality': currentQuality};

        if (size <= targetSizeBytes) {
          AppLogger.log('Target size achieved at $currentQuality% quality');
          break;
        }
      } catch (e) {
        AppLogger.error('Compression attempt $attempts failed', e);
        break;
      }

      currentQuality -= _qualityStep;
    }

    final finalResult = bestResult ?? {'uri': uri, 'size': originalSize, 'quality': 100};
    final compressionRatio = originalSize > 0
        ? ((originalSize - (finalResult['size'] as int)) / originalSize * 100).toDouble()
        : 0.0;

    return {
      ...finalResult,
      'originalSize': originalSize,
      'compressionRatio': double.parse(compressionRatio.toStringAsFixed(1)),
      'isUnderTargetSize': (finalResult['size'] as int) <= targetSizeBytes,
    };
  } catch (e) {
    AppLogger.error('Compression process failed', e);
    rethrow;
  }
}

/// Simple wrapper — returns compressed URI or original on failure.
Future<String> compressImage(String uri) async {
  try {
    final result = await compressToSize(uri);
    return result['uri'] as String;
  } catch (e) {
    AppLogger.error('Simple compression failed', e);
    return uri;
  }
}

Future<List<Map<String, dynamic>>> compressMultipleImages(
  List<String> uris, {
  int targetSizeBytes = _maxFileSizeBytes,
}) async {
  final results = <Map<String, dynamic>>[];
  for (var i = 0; i < uris.length; i++) {
    AppLogger.log('Compressing image ${i + 1}/${uris.length}');
    try {
      final result = await compressToSize(uris[i], targetSizeBytes: targetSizeBytes);
      results.add({'index': i, 'success': true, ...result});
    } catch (e) {
      AppLogger.error('Failed to compress image ${i + 1}', e);
      results.add({'index': i, 'success': false, 'error': e.toString(), 'originalUri': uris[i]});
    }
  }
  return results;
}

Future<bool> needsCompression(String uri, {int targetSizeBytes = _maxFileSizeBytes}) async {
  try {
    return (await _getFileSize(uri)) > targetSizeBytes;
  } catch (e) {
    AppLogger.error('Error checking if compression needed', e);
    return false;
  }
}

Future<Map<String, dynamic>> getCompressionInfo(String uri) async {
  final size = await _getFileSize(uri);
  final sizeMB = size / 1024 / 1024;
  final needed = size > _maxFileSizeBytes;
  final recommendedQuality = needed
      ? (_maxFileSizeBytes / size * 100).clamp(_minQuality.toDouble(), 100.0).round()
      : 100;

  return {
    'currentSize': size,
    'currentSizeMB': double.parse(sizeMB.toStringAsFixed(2)),
    'needsCompression': needed,
    'recommendedQuality': recommendedQuality,
    'estimatedFinalSizeMB': double.parse((sizeMB * recommendedQuality / 100).toStringAsFixed(2)),
  };
}
