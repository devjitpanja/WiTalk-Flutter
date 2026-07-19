import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../api/dio_client.dart';
import '../api/app_endpoints.dart';

const _kCacheKey = 'cached_location_data';
const _kCacheTtlMs = 30 * 60 * 1000; // 30 min
const _kTrackingIntervalMs = 5 * 60 * 1000; // 5 min
const _kMinMoveMeters = 500.0;

class CachedLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? city;
  final String? country;
  final String? state;
  final String? source;
  final int timestamp;

  const CachedLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.city,
    this.country,
    this.state,
    this.source,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch - timestamp > _kCacheTtlMs;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'city': city,
        'country': country,
        'state': state,
        'source': source,
        'timestamp': timestamp,
      };

  factory CachedLocation.fromJson(Map<String, dynamic> j) => CachedLocation(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        city: j['city'] as String?,
        country: j['country'] as String?,
        state: j['state'] as String?,
        source: j['source'] as String?,
        timestamp: (j['timestamp'] as num).toInt(),
      );
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  CachedLocation? _lastKnownLocation;
  Timer? _trackingTimer;
  bool _isRefreshingBackground = false;

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> checkPermission() async {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<bool> requestPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  Future<CachedLocation?> _readCache({bool ignoreExpiry = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return null;
      final loc = CachedLocation.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
      if (!ignoreExpiry && loc.isExpired) return null;
      return loc;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(CachedLocation loc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCacheKey, jsonEncode(loc.toJson()));
  }

  // ── Core location resolution ───────────────────────────────────────────────

  /// Main resolution waterfall — mirrors RN locationService.getSingleLocation.
  /// [forceRefresh] skips the app cache and always gets fresh GPS.
  /// [quickMode] uses shorter timeout, used on pull-to-refresh.
  Future<CachedLocation> getLocation({
    bool forceRefresh = false,
    bool quickMode = false,
  }) async {
    // Step 1: App cache (if not forcing refresh)
    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) {
        _refreshInBackground();
        return cached;
      }
    }

    // Step 2: OS cached fix via getLastKnownPosition (instant)
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final loc = CachedLocation(
          latitude: last.latitude,
          longitude: last.longitude,
          accuracy: last.accuracy,
          source: 'os_cache',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        await _writeCache(loc);
        if (!quickMode) _refreshInBackground();
        return loc;
      }
    } catch (_) {}

    // Step 3: Fresh GPS fix
    final timeoutSec = quickMode ? 8 : 15;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(Duration(seconds: timeoutSec));
      final loc = CachedLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        source: 'gps',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await _writeCache(loc);
      return loc;
    } catch (_) {}

    // Step 4: Expired cache as last resort
    final stale = await _readCache(ignoreExpiry: true);
    if (stale != null) return stale;

    throw Exception('Unable to get your location');
  }

  void _refreshInBackground() {
    if (_isRefreshingBackground) return;
    _isRefreshingBackground = true;
    Future.delayed(Duration.zero, () async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 15));
        final loc = CachedLocation(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          source: 'gps_background',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        await _writeCache(loc);
      } catch (_) {} finally {
        _isRefreshingBackground = false;
      }
    });
  }

  /// Warm the cache at app startup using the OS-cached fix (no GPS spin-up).
  Future<void> warmCache() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        await _writeCache(CachedLocation(
          latitude: last.latitude,
          longitude: last.longitude,
          accuracy: last.accuracy,
          source: 'os_cache',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    } catch (_) {}
  }

  // ── Reverse geocode (Nominatim) ────────────────────────────────────────────

  Future<Map<String, String?>> reverseGeocode(
      double lat, double lon) async {
    try {
      final res = await Dio().get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': lat,
          'lon': lon,
          'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'WiTalk/1.0'}),
      ).timeout(const Duration(seconds: 8));
      final addr = (res.data as Map?)?['address'] as Map? ?? {};
      return {
        'city': (addr['city'] ?? addr['town'] ?? addr['village'] ??
                addr['county']) as String?,
        'state': addr['state'] as String?,
        'country': addr['country'] as String?,
      };
    } catch (_) {
      return {'city': null, 'state': null, 'country': null};
    }
  }

  // ── Server update ──────────────────────────────────────────────────────────

  /// Gets fresh location, reverse-geocodes it, and POSTs to /v1/location/update.
  /// Skips server call if user moved <500m since last update (unless [forceUpdate]).
  Future<void> getCurrentLocationAndUpdate(String uid,
      {bool forceUpdate = false}) async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return;

    try {
      final loc = await getLocation(forceRefresh: forceUpdate);

      // Skip if barely moved
      if (!forceUpdate && _lastKnownLocation != null) {
        final dist = _haversineMeters(
          _lastKnownLocation!.latitude,
          _lastKnownLocation!.longitude,
          loc.latitude,
          loc.longitude,
        );
        if (dist < _kMinMoveMeters) return;
      }

      final geo = await reverseGeocode(loc.latitude, loc.longitude);
      final city = geo['city'];
      final state = geo['state'];
      final country = geo['country'];

      // Cache geo data too
      final enriched = CachedLocation(
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracy: loc.accuracy,
        city: city,
        state: state,
        country: country,
        source: loc.source,
        timestamp: loc.timestamp,
      );
      await _writeCache(enriched);

      await dioClient.post(AppEndpoints.updateLocation, data: {
        'uid': uid,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'city': city,
        'state': state,
        'country': country,
      }, options: Options(headers: {'x-location-source': 'app-foreground'}));

      _lastKnownLocation =
          CachedLocation(latitude: loc.latitude, longitude: loc.longitude, timestamp: loc.timestamp);
    } catch (_) {}
  }

  /// Update only city/state on the user profile (startup shortcut).
  Future<void> updateCityOnStartup(String uid) async {
    try {
      final loc = await getLocation();
      final geo = await reverseGeocode(loc.latitude, loc.longitude);
      if (geo['city'] != null || geo['state'] != null) {
        await dioClient.put(
          AppEndpoints.updateProfile(uid),
          data: {'city': geo['city'], 'state': geo['state']},
        );
      }
    } catch (_) {}
  }

  // ── Periodic tracking ──────────────────────────────────────────────────────

  void startTracking(String uid) {
    if (_trackingTimer != null) return;
    _trackingTimer = Timer.periodic(
      const Duration(milliseconds: _kTrackingIntervalMs),
      (_) => getCurrentLocationAndUpdate(uid),
    );
  }

  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;
}

final locationService = LocationService();
