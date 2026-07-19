import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';

const _kSeenPermissionKey = 'hasSeenLocationPermissionScreen';
const _kFilterGenderKey = 'nearbyPeopleGender';
const _kFilterMinAgeKey = 'nearbyPeopleMinAge';
const _kFilterMaxAgeKey = 'nearbyPeopleMaxAge';
const _kFilterMaxDistKey = 'nearbyPeopleMaxDistance';

// ── Location permission status ────────────────────────────────────────────────

class LocationPermissionState {
  final bool granted;
  final bool hasSeenScreen;

  const LocationPermissionState({
    this.granted = false,
    this.hasSeenScreen = false,
  });

  LocationPermissionState copyWith({bool? granted, bool? hasSeenScreen}) =>
      LocationPermissionState(
        granted: granted ?? this.granted,
        hasSeenScreen: hasSeenScreen ?? this.hasSeenScreen,
      );
}

class LocationPermissionNotifier
    extends StateNotifier<LocationPermissionState> {
  LocationPermissionNotifier() : super(const LocationPermissionState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_kSeenPermissionKey) ?? false;
    final granted = await locationService.checkPermission();
    state = state.copyWith(granted: granted, hasSeenScreen: hasSeen);
  }

  Future<bool> requestPermission() async {
    final granted = await locationService.requestPermission();
    state = state.copyWith(granted: granted);
    return granted;
  }

  Future<void> markScreenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenPermissionKey, true);
    state = state.copyWith(hasSeenScreen: true);
  }

  Future<void> recheck() async {
    final granted = await locationService.checkPermission();
    state = state.copyWith(granted: granted);
  }
}

final locationPermissionProvider =
    StateNotifierProvider<LocationPermissionNotifier, LocationPermissionState>(
  (ref) => LocationPermissionNotifier(),
);

// ── Nearby filter prefs ───────────────────────────────────────────────────────

class NearbyFilterState {
  final String gender; // 'all' | 'male' | 'female'
  final int minAge;
  final int maxAge;
  final int maxDistanceKm;

  const NearbyFilterState({
    this.gender = 'all',
    this.minAge = 18,
    this.maxAge = 60,
    this.maxDistanceKm = 500,
  });

  NearbyFilterState copyWith({
    String? gender,
    int? minAge,
    int? maxAge,
    int? maxDistanceKm,
  }) =>
      NearbyFilterState(
        gender: gender ?? this.gender,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      );
}

class NearbyFilterNotifier extends StateNotifier<NearbyFilterState> {
  NearbyFilterNotifier() : super(const NearbyFilterState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NearbyFilterState(
      gender: prefs.getString(_kFilterGenderKey) ?? 'all',
      minAge: prefs.getInt(_kFilterMinAgeKey) ?? 18,
      maxAge: prefs.getInt(_kFilterMaxAgeKey) ?? 60,
      maxDistanceKm: prefs.getInt(_kFilterMaxDistKey) ?? 500,
    );
  }

  Future<void> update({String? gender, int? minAge, int? maxAge, int? maxDist}) async {
    state = state.copyWith(
      gender: gender,
      minAge: minAge,
      maxAge: maxAge,
      maxDistanceKm: maxDist,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFilterGenderKey, state.gender);
    await prefs.setInt(_kFilterMinAgeKey, state.minAge);
    await prefs.setInt(_kFilterMaxAgeKey, state.maxAge);
    await prefs.setInt(_kFilterMaxDistKey, state.maxDistanceKm);
  }
}

final nearbyFilterProvider =
    StateNotifierProvider<NearbyFilterNotifier, NearbyFilterState>(
  (ref) => NearbyFilterNotifier(),
);
