import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/app_endpoints.dart';
import '../api/dio_client.dart';
import '../services/location_service.dart';
import 'auth_provider.dart';

// Polls the nearby API every 5 minutes and exposes a boolean — true if any
// user within 500 m is online or was active today.
final nearbyOnlineProvider =
    StateNotifierProvider<NearbyOnlineNotifier, bool>((ref) {
  return NearbyOnlineNotifier(ref);
});

class NearbyOnlineNotifier extends StateNotifier<bool> {
  final Ref _ref;

  NearbyOnlineNotifier(this._ref) : super(false) {
    _check();
    _startPolling();
  }

  static const _pollInterval = Duration(minutes: 5);

  Future<void> _check() async {
    try {
      final uid = _ref.read(authProvider).uid;
      if (uid == null || uid.isEmpty) return;

      final loc = await locationService.getLocation(forceRefresh: false);

      final res = await dioClient.get(
        AppEndpoints.nearbyPeople,
        queryParameters: {
          'uid': uid,
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'radius': 500,
        },
      );

      final data = res.data;
      final users = (data is Map
              ? (data['users'] ?? data['data']?['users'] ?? data['data'])
              : null) ??
          [];

      if (users is! List) {
        state = false;
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final hasOnline = users.any((u) {
        if (u is! Map) return false;
        if (u['is_online'] == true) return true;
        final lastSeen = u['last_seen'];
        if (lastSeen == null) return false;
        try {
          final diff =
              now - DateTime.parse(lastSeen.toString()).millisecondsSinceEpoch;
          return diff < 86400000; // active today
        } catch (_) {
          return false;
        }
      });

      if (mounted) state = hasOnline;
    } catch (_) {
      // silently ignore — dot simply stays off
    }
  }

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(_pollInterval);
      if (!mounted) return false;
      await _check();
      return mounted;
    });
  }

  // Called by NearbyPeopleScreen when it has fresh results
  void setHasOnlineNearby(bool value) {
    if (mounted) state = value;
  }
}
