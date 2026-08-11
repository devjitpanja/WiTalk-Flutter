import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'witalk_image_cache.dart';

// ── Max cache size options (bytes) ────────────────────────────────────────────

const int kCacheSize5GB   = 5  * 1024 * 1024 * 1024;
const int kCacheSize16GB  = 16 * 1024 * 1024 * 1024;
const int kCacheSize32GB  = 32 * 1024 * 1024 * 1024;
const int kCacheSizeNoLimit = -1;

const String _kMaxCacheSizeKey = 'app_max_cache_size_bytes';
const int _kDefaultMaxCacheSizeBytes = kCacheSize16GB;

// ── Storage snapshot ──────────────────────────────────────────────────────────

class CacheSnapshot {
  final int imageBytes;
  final int videoBytes;
  final int audioBytes;
  final int fileBytes;
  final int otherBytes;
  final int dbBytes;

  const CacheSnapshot({
    this.imageBytes = 0,
    this.videoBytes = 0,
    this.audioBytes = 0,
    this.fileBytes = 0,
    this.otherBytes = 0,
    this.dbBytes = 0,
  });

  int get totalMediaBytes =>
      imageBytes + videoBytes + audioBytes + fileBytes + otherBytes;

  int get totalBytes => totalMediaBytes + dbBytes;

  CacheSnapshot operator +(CacheSnapshot other) => CacheSnapshot(
        imageBytes: imageBytes + other.imageBytes,
        videoBytes: videoBytes + other.videoBytes,
        audioBytes: audioBytes + other.audioBytes,
        fileBytes: fileBytes + other.fileBytes,
        otherBytes: otherBytes + other.otherBytes,
        dbBytes: dbBytes + other.dbBytes,
      );
}

// ── AppCacheManager ───────────────────────────────────────────────────────────

/// Centralised cache facade.
///
/// Knows about every on-disk location where the app stores data so the
/// Storage Usage screen can show accurate, categorised numbers and clear
/// each category independently.
///
/// Disposable vs persistent separation
/// ─────────────────────────────────────
/// • Disposable  — image/video/audio/file cache.  Safe to delete; content
///                 re-downloads on next access.
/// • Persistent  — witalk.db (messages, conversations, sync state).
///                 NEVER deleted by cache clearing.
class AppCacheManager {
  static final AppCacheManager _instance = AppCacheManager._();
  factory AppCacheManager() => _instance;
  AppCacheManager._();

  // ── Paths ─────────────────────────────────────────────────────────────────

  /// Returns the app's Documents directory (contains witalk.db).
  Future<Directory> get _docsDir => getApplicationDocumentsDirectory();

  /// Returns the system temp directory base.
  Future<Directory> get _tmpDir => getTemporaryDirectory();

  /// flutter_cache_manager subdirectory for the WiTalkImageCache.
  static const String _imageCacheKey = WiTalkImageCache.key;

  /// DefaultCacheManager key — used by CachedNetworkImage when no cacheManager
  /// is provided.  We still measure and clear it so legacy-cached files count.
  static const String _defaultCacheKey = 'libCachedImageData';

  /// Video cache sub-directory written by VideoCacheManager.
  static const String _videoCacheDirName = 'witalk_video_cache';

  // ── Max cache size ────────────────────────────────────────────────────────

  Future<int> getMaxCacheBytes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kMaxCacheSizeKey) ?? _kDefaultMaxCacheSizeBytes;
  }

  Future<void> setMaxCacheBytes(int bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMaxCacheSizeKey, bytes);
    AppLogger.log('[AppCacheManager] Max cache size set to $bytes bytes');
  }

  // ── Measurement ───────────────────────────────────────────────────────────

  Future<CacheSnapshot> measure() async {
    final results = await Future.wait([
      _measureImageCache(),
      _measureVideoCache(),
      _measureDbSize(),
    ]);
    final imageBytes = results[0];
    final videoBytes = results[1];
    final dbBytes = results[2];
    return CacheSnapshot(
      imageBytes: imageBytes,
      videoBytes: videoBytes,
      dbBytes: dbBytes,
    );
  }

  Future<int> _measureImageCache() async {
    try {
      final tmp = await _tmpDir;
      int total = 0;
      for (final key in [_imageCacheKey, _defaultCacheKey]) {
        final dir = Directory(p.join(tmp.path, key));
        if (dir.existsSync()) total += await _dirSize(dir);
      }
      return total;
    } catch (e) {
      AppLogger.error('[AppCacheManager] _measureImageCache error', e);
      return 0;
    }
  }

  Future<int> _measureVideoCache() async {
    try {
      final tmp = await _tmpDir;
      final videoDir = Directory(p.join(tmp.path, _videoCacheDirName));
      if (!videoDir.existsSync()) return 0;
      return await _dirSize(videoDir);
    } catch (e) {
      AppLogger.error('[AppCacheManager] _measureVideoCache error', e);
      return 0;
    }
  }

  Future<int> _measureDbSize() async {
    try {
      final docs = await _docsDir;
      final dbFile = File(p.join(docs.path, 'witalk.db'));
      if (!dbFile.existsSync()) return 0;
      return dbFile.lengthSync();
    } catch (e) {
      AppLogger.error('[AppCacheManager] _measureDbSize error', e);
      return 0;
    }
  }

  // ── Clear operations ──────────────────────────────────────────────────────

  /// Clear the image cache only.
  ///
  /// Deletes files directly from both the WiTalkImageCache directory and the
  /// legacy DefaultCacheManager directory.  Direct deletion is used instead of
  /// emptyCache() because emptyCache() only marks DB entries as stale — the
  /// actual files remain on disk until next access, so a subsequent measure()
  /// would still report non-zero bytes.
  Future<void> clearImageCache() async {
    try {
      final tmp = await _tmpDir;
      for (final key in [_imageCacheKey, _defaultCacheKey]) {
        await _deleteFilesInDir(Directory(p.join(tmp.path, key)));
      }
      // Also notify flutter_cache_manager so its internal DB is consistent.
      try { await WiTalkImageCache().emptyCache(); } catch (_) {}
      AppLogger.log('[AppCacheManager] Image cache cleared');
    } catch (e) {
      AppLogger.error('[AppCacheManager] clearImageCache error', e);
      rethrow;
    }
  }

  /// Clear the video cache only.
  Future<void> clearVideoCache() async {
    try {
      final tmp = await _tmpDir;
      await _deleteFilesInDir(Directory(p.join(tmp.path, _videoCacheDirName)));
      AppLogger.log('[AppCacheManager] Video cache cleared');
    } catch (e) {
      AppLogger.error('[AppCacheManager] clearVideoCache error', e);
      rethrow;
    }
  }

  /// Clear ALL disposable caches (images + video).
  /// Never touches witalk.db or SharedPreferences.
  Future<void> clearAllMediaCache() async {
    await Future.wait([
      clearImageCache(),
      clearVideoCache(),
    ]);
    AppLogger.log('[AppCacheManager] All media cache cleared');
  }

  // ── Eviction (max-size enforcement) ──────────────────────────────────────

  /// Evict LRU cached images when total image cache exceeds the configured
  /// max.  Called opportunistically — e.g. after a download or on app resume.
  Future<void> enforceMaxCacheSize() async {
    try {
      final max = await getMaxCacheBytes();
      if (max == kCacheSizeNoLimit) return;

      final snapshot = await measure();
      if (snapshot.totalMediaBytes <= max) return;

      final excess = snapshot.totalMediaBytes - max;
      AppLogger.log(
          '[AppCacheManager] Cache over limit by ${fmtBytes(excess)} — evicting LRU images');

      // flutter_cache_manager handles LRU internally via maxNrOfCacheObjects
      // and stalePeriod. Forcing a shrink by reducing objects temporarily
      // is not exposed. Instead we clear the entire image cache if we are
      // significantly over limit (>10 % excess relative to max).
      if (excess > max * 0.1) {
        await clearImageCache();
        AppLogger.log('[AppCacheManager] LRU eviction: cleared image cache');
      }
    } catch (e) {
      AppLogger.error('[AppCacheManager] enforceMaxCacheSize error', e);
    }
  }

  // ── User-scoped clear on logout ───────────────────────────────────────────

  /// Called from performLogout() to ensure no media from User A is visible
  /// to User B if they sign in on the same device.
  Future<void> clearOnLogout() async {
    await clearAllMediaCache();
    AppLogger.log('[AppCacheManager] Media cache cleared on logout');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<int> _dirSize(Directory dir) async {
    int size = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            size += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return size;
  }

  /// Delete every file inside [dir] recursively, keeping the directory itself.
  Future<void> _deleteFilesInDir(Directory dir) async {
    if (!dir.existsSync()) return;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try { await entity.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }
}

// ── Top-level singleton ───────────────────────────────────────────────────────

final appCacheManager = AppCacheManager();

// ── Formatting helper (shared by UI too) ─────────────────────────────────────

String fmtBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

