import 'package:dio/dio.dart';
import 'logger.dart';

class VideoPrefetchManager {
  static final VideoPrefetchManager _instance = VideoPrefetchManager._();
  factory VideoPrefetchManager() => _instance;
  VideoPrefetchManager._();

  final Map<String, Map<String, dynamic>> _prefetchedVideos = {};
  final List<Map<String, dynamic>> _prefetchQueue = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final _dio = Dio();

  static const Duration _prefetchTimeWindow = Duration(minutes: 5);
  bool _isProcessing = false;

  void prefetchUpcoming(List<Map<String, dynamic>> videos, int currentIndex, {int lookahead = 2}) {
    if (videos.isEmpty) return;
    _prefetchQueue.clear();

    for (var i = 1; i <= lookahead; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < videos.length) {
        final url = videos[nextIndex]['videoUrl'] as String?;
        if (url != null) {
          _prefetchQueue.add({'url': url, 'index': nextIndex, 'priority': i});
        }
      }
    }

    AppLogger.log('[VideoPrefetch] Queue: ${_prefetchQueue.length} videos');
    _processPrefetchQueue();
  }

  Future<void> _processPrefetchQueue() async {
    if (_isProcessing || _prefetchQueue.isEmpty) return;
    _isProcessing = true;

    _prefetchQueue.sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));

    for (final item in List.from(_prefetchQueue)) {
      final url = item['url'] as String;
      if (_isPrefetched(url)) {
        AppLogger.log('[VideoPrefetch] Skipping already prefetched: index ${item['index']}');
        continue;
      }
      try {
        await _prefetchVideo(url, item['index'] as int);
      } catch (e) {
        AppLogger.error('[VideoPrefetch] Error prefetching index ${item['index']}', e);
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isProcessing = false;
  }

  Future<void> _prefetchVideo(String videoUrl, int index) async {
    AppLogger.log('[VideoPrefetch] Prefetching index $index');
    final cancelToken = CancelToken();
    _cancelTokens[videoUrl] = cancelToken;

    try {
      if (videoUrl.contains('.m3u8')) {
        final response = await _dio.get<String>(
          videoUrl,
          cancelToken: cancelToken,
          options: Options(responseType: ResponseType.plain),
        );
        if (response.data != null) {
          await _prefetchHLSSegments(response.data!, videoUrl, cancelToken);
        }
      } else {
        await _prefetchPartialVideo(videoUrl, cancelToken);
      }

      _prefetchedVideos[videoUrl] = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'success',
      };
      AppLogger.log('[VideoPrefetch] Prefetched index $index');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        AppLogger.log('[VideoPrefetch] Prefetch aborted for index $index');
      } else {
        AppLogger.error('[VideoPrefetch] Failed to prefetch index $index', e);
        _prefetchedVideos[videoUrl] = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': 'failed',
        };
      }
    } finally {
      _cancelTokens.remove(videoUrl);
    }
  }

  Future<void> _prefetchHLSSegments(String manifest, String baseUrl, CancelToken cancelToken) async {
    final lines = manifest.split('\n');
    final segmentUrls = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#') &&
          (trimmed.contains('.ts') || trimmed.contains('.m4s'))) {
        final segUrl = trimmed.startsWith('http') ? trimmed : _resolveUrl(baseUrl, trimmed);
        segmentUrls.add(segUrl);
        if (segmentUrls.length >= 2) break;
      }
    }

    for (final segUrl in segmentUrls) {
      try {
        await _dio.get<List<int>>(
          segUrl,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Cache-Control': 'max-age=3600'},
          ),
        );
        AppLogger.log('[VideoPrefetch] Prefetched HLS segment');
      } on DioException catch (e) {
        if (e.type != DioExceptionType.cancel) {
          AppLogger.error('[VideoPrefetch] Segment prefetch error', e);
        }
      }
    }
  }

  Future<void> _prefetchPartialVideo(String videoUrl, CancelToken cancelToken) async {
    try {
      await _dio.get<List<int>>(
        videoUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Range': 'bytes=0-524288', 'Cache-Control': 'max-age=3600'},
        ),
      );
      AppLogger.log('[VideoPrefetch] Prefetched partial video (first 512KB)');
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        AppLogger.error('[VideoPrefetch] Partial video prefetch error', e);
      }
    }
  }

  String _resolveUrl(String baseUrl, String relativePath) {
    try {
      final uri = Uri.parse(baseUrl);
      final basePath = uri.path.substring(0, uri.path.lastIndexOf('/') + 1);
      return '${uri.scheme}://${uri.host}$basePath$relativePath';
    } catch (_) {
      return relativePath;
    }
  }

  bool _isPrefetched(String videoUrl) {
    final data = _prefetchedVideos[videoUrl];
    if (data == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - (data['timestamp'] as int);
    return age < _prefetchTimeWindow.inMilliseconds && data['status'] == 'success';
  }

  void cancelAll() {
    AppLogger.log('[VideoPrefetch] Cancelling all prefetch operations');
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _cancelTokens.clear();
    _prefetchQueue.clear();
    _isProcessing = false;
  }

  void cleanup() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _prefetchedVideos.removeWhere(
      (_, data) => (now - (data['timestamp'] as int)) > _prefetchTimeWindow.inMilliseconds,
    );
  }

  void clear() {
    cancelAll();
    _prefetchedVideos.clear();
  }

  Map<String, dynamic> getStats() => {
    'totalPrefetched': _prefetchedVideos.length,
    'queueLength': _prefetchQueue.length,
    'isProcessing': _isProcessing,
    'activeRequests': _cancelTokens.length,
  };
}

final videoPrefetchManager = VideoPrefetchManager();
