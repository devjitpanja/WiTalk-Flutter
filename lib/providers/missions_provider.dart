import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../api/app_endpoints.dart';
import '../api/dio_client.dart';
import 'auth_provider.dart';

// True when there are missions the user can collect (completed but unclaimed).
// Re-checked when the app resumes. Consumed by ShellScreen and AccountOverviewScreen.
final hasUnclaimedMissionsProvider =
    StateNotifierProvider<UnclaimedMissionsNotifier, bool>((ref) {
  return UnclaimedMissionsNotifier(ref);
});

class UnclaimedMissionsNotifier extends StateNotifier<bool> {
  final Ref _ref;

  UnclaimedMissionsNotifier(this._ref) : super(false) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final uid = _ref.read(authProvider).uid;
      if (uid == null || uid.isEmpty) return;

      final info = await PackageInfo.fromPlatform();
      final res = await dioClient.get(
        AppEndpoints.userMissions(uid),
        queryParameters: {'appVersion': info.version},
      );

      final data = res.data;
      if (data is! Map || data['success'] != true) return;

      final missionData = data['data'];
      if (missionData is! Map) return;

      final daily = (missionData['daily'] as List?) ?? [];
      final lifetime = (missionData['lifetime'] as List?) ?? [];
      final all = [...daily, ...lifetime];

      final count = all.where((m) => m is Map && m['canCollect'] == true).length;

      if (mounted) state = count > 0;
    } catch (_) {
      // silently ignore
    }
  }
}
