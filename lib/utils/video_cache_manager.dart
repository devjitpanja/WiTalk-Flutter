import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'logger.dart';

/// Video cache manager using the filesystem.
///
/// On Flutter/Android, video_player already uses ExoPlayer which has built-in
/// cache via DefaultHttpDataSource. This class provides supplemental app-level
/// cache tracking and statistics.
///
/// For a full ExoPlayer proxy cache (matching the RN native module), wire up a
/// platform channel to Android's ProxyCache library on the native side.
class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._();
  factory VideoCacheManager() => _instance;
  VideoCacheManager._();

  final Map<String, Map<String, dynamic>> _cacheIndex = {};
  int _maxSizeBytes = 500 * 1024 * 1024; // 500 MB default
  Directory? _cacheDir;

  Future<Directory> get _dir async {
    _cacheDir ??= Directory('${(await getTemporaryDirectory()).path}/witalk_video_cache')
      ..createSync(recursive: true);
    return _cacheDir!;
  }

  Future<void> initialize({int maxSizeMb = 500}) async {
    _maxSizeBytes = maxSizeMb * 1024 * 1024;
    await _dir;
    AppLogger.log('[VideoCacheManager] Initialized (max ${maxSizeMb}MB)');
  }

  /// Returns the URL as-is (passthrough). For native proxy caching,
  /// implement a platform channel that returns an ExoPlayer proxy URL.
  Future<String> getCachedUrl(String videoUrl) async {
    return videoUrl;
  }

  Future<Map<String, dynamic>> getCacheStatus(String videoUrl) async {
    return _cacheIndex[videoUrl] ?? {'isCached': false, 'cachedBytes': 0};
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final dir = await _dir;
      int totalSize = 0;
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) totalSize += entity.lengthSync();
      }
      return {
        'currentSize': totalSize,
        'maxSize': _maxSizeBytes,
        'usedPercentage': _maxSizeBytes > 0 ? (totalSize / _maxSizeBytes * 100) : 0.0,
      };
    } catch (e) {
      AppLogger.error('[VideoCacheManager] getStats error', e);
      return {'currentSize': 0, 'maxSize': _maxSizeBytes, 'usedPercentage': 0.0};
    }
  }

  Future<Map<String, dynamic>> clearCache() async {
    try {
      final dir = await _dir;
      int count = 0;
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          entity.deleteSync();
          count++;
        }
      }
      _cacheIndex.clear();
      AppLogger.log('[VideoCacheManager] Cache cleared ($count files)');
      return {'clearedCount': count, 'message': 'Cache cleared ($count files)'};
    } catch (e) {
      AppLogger.error('[VideoCacheManager] clearCache error', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> clearCacheForUrl(String videoUrl) async {
    _cacheIndex.remove(videoUrl);
    return {'success': true, 'message': 'Cache entry removed for $videoUrl'};
  }

  Future<void> logStats() async {
    final stats = await getStats();
    final currentMB = ((stats['currentSize'] as int) / 1024 / 1024).toStringAsFixed(2);
    final maxMB = ((stats['maxSize'] as int) / 1024 / 1024).toStringAsFixed(2);
    AppLogger.separator('Video Cache Statistics');
    AppLogger.log('  Current Size: ${currentMB}MB');
    AppLogger.log('  Max Size: ${maxMB}MB');
    AppLogger.log('  Used: ${(stats['usedPercentage'] as double).toStringAsFixed(2)}%');
    AppLogger.separator();
  }
}

final videoCacheManager = VideoCacheManager();
