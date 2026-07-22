class _Metrics {
  int renderCount = 0;
  double averageRenderTime = 0;
  int markerCount = 0;
  int clusterCount = 0;
  int apiCallCount = 0;
  double averageApiTime = 0;
  int totalUsers = 0;
  int visibleUsers = 0;
  double cacheHitRate = 0;
}

class PerformanceMonitor {
  final _metrics = _Metrics();
  final List<double> _renderTimes = [];
  final List<double> _apiTimes = [];
  static const _maxSamples = 100;

  Stopwatch startRender() => Stopwatch()..start();

  double endRender(Stopwatch sw, {int markerCount = 0, int clusterCount = 0}) {
    sw.stop();
    final renderTime = sw.elapsedMicroseconds / 1000.0;
    _renderTimes.add(renderTime);
    if (_renderTimes.length > _maxSamples) _renderTimes.removeAt(0);
    _metrics.renderCount++;
    _metrics.markerCount = markerCount;
    _metrics.clusterCount = clusterCount;
    _metrics.averageRenderTime = _average(_renderTimes);
    return renderTime;
  }

  Stopwatch startApiCall() => Stopwatch()..start();

  double endApiCall(Stopwatch sw, {int userCount = 0}) {
    sw.stop();
    final apiTime = sw.elapsedMicroseconds / 1000.0;
    _apiTimes.add(apiTime);
    if (_apiTimes.length > _maxSamples) _apiTimes.removeAt(0);
    _metrics.apiCallCount++;
    _metrics.totalUsers = userCount;
    _metrics.averageApiTime = _average(_apiTimes);
    return apiTime;
  }

  void updateVisibleUsers(int count) => _metrics.visibleUsers = count;

  void updateCacheHitRate(int hits, int total) {
    _metrics.cacheHitRate = total > 0 ? (hits / total) * 100 : 0;
  }

  double _average(List<double> list) {
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  int get _fps {
    if (_metrics.averageRenderTime == 0) return 60;
    return (1000 / _metrics.averageRenderTime).floor().clamp(0, 60);
  }

  Map<String, dynamic> getMetrics() => {
    'renderCount': _metrics.renderCount,
    'averageRenderTime': _metrics.averageRenderTime,
    'markerCount': _metrics.markerCount,
    'clusterCount': _metrics.clusterCount,
    'apiCallCount': _metrics.apiCallCount,
    'averageApiTime': _metrics.averageApiTime,
    'totalUsers': _metrics.totalUsers,
    'visibleUsers': _metrics.visibleUsers,
    'cacheHitRate': _metrics.cacheHitRate,
    'fps': _fps,
  };

  Map<String, dynamic> getReport() => {
    'summary': {
      'totalRenders': _metrics.renderCount,
      'totalApiCalls': _metrics.apiCallCount,
      'averageRenderTime': '${_metrics.averageRenderTime.toStringAsFixed(2)}ms',
      'averageApiTime': '${_metrics.averageApiTime.toStringAsFixed(2)}ms',
      'estimatedFPS': _fps,
    },
    'currentState': {
      'totalUsers': _metrics.totalUsers,
      'visibleUsers': _metrics.visibleUsers,
      'markerCount': _metrics.markerCount,
      'clusterCount': _metrics.clusterCount,
      'clusteringActive': _metrics.clusterCount > 0,
    },
    'efficiency': {
      'cacheHitRate': '${_metrics.cacheHitRate.toStringAsFixed(1)}%',
      'renderEfficiency': _metrics.visibleUsers > 0
          ? '${((_metrics.markerCount / _metrics.visibleUsers) * 100).toStringAsFixed(1)}%'
          : 'N/A',
    },
  };

  bool isPerformanceGood() =>
      _metrics.averageRenderTime < 16 &&
      _metrics.averageApiTime < 1000 &&
      _fps >= 55;

  List<Map<String, dynamic>> getWarnings() {
    final warnings = <Map<String, dynamic>>[];

    if (_metrics.averageRenderTime > 16) {
      warnings.add({
        'type': 'render',
        'message': 'Render time (${_metrics.averageRenderTime.toStringAsFixed(2)}ms) exceeds 16ms target',
        'severity': 'high',
      });
    }
    if (_metrics.averageApiTime > 2000) {
      warnings.add({
        'type': 'api',
        'message': 'API calls taking too long (${_metrics.averageApiTime.toStringAsFixed(2)}ms)',
        'severity': 'medium',
      });
    }
    if (_fps < 30) {
      warnings.add({'type': 'fps', 'message': 'Low FPS detected ($_fps)', 'severity': 'high'});
    }
    if (_metrics.visibleUsers > 1000 && _metrics.clusterCount == 0) {
      warnings.add({
        'type': 'clustering',
        'message': 'Too many visible users (${_metrics.visibleUsers}) without clustering',
        'severity': 'high',
      });
    }
    return warnings;
  }

  void reset() {
    _renderTimes.clear();
    _apiTimes.clear();
    _metrics.renderCount = 0;
    _metrics.averageRenderTime = 0;
    _metrics.markerCount = 0;
    _metrics.clusterCount = 0;
    _metrics.apiCallCount = 0;
    _metrics.averageApiTime = 0;
    _metrics.totalUsers = 0;
    _metrics.visibleUsers = 0;
    _metrics.cacheHitRate = 0;
  }
}

final performanceMonitor = PerformanceMonitor();
