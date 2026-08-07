import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../utils/storage.dart';
import '../utils/logger.dart';

const _kCacheKey = 'cachedUserProfile';

class UserProfile {
  final String id;
  final String name;
  final String? username;
  final String? email;
  final String? profilePic;
  final String? gender;
  final String? city;
  final String? country;
  final String? birthday;
  final bool isVerified;
  final String accountType; // 'personal' | 'professional'
  final Map<String, dynamic>? verificationBadge;
  final Map<String, dynamic>? access; // e.g. {can_post: bool}

  const UserProfile({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.profilePic,
    this.gender,
    this.city,
    this.country,
    this.birthday,
    this.isVerified = false,
    this.accountType = 'personal',
    this.verificationBadge,
    this.access,
  });

  bool get isProfessional => accountType == 'professional';

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] ?? json['uid'] ?? '',
        name: json['name'] ?? '',
        username: json['username'],
        email: json['email'],
        profilePic: json['profile_pic'],
        gender: json['gender'],
        city: json['city'],
        country: json['country'],
        birthday: json['birthday'],
        isVerified: json['is_verified'] == true,
        accountType: (json['account_type'] as String?) ?? 'personal',
        verificationBadge: json['verification_badge'] is Map
            ? Map<String, dynamic>.from(json['verification_badge'] as Map)
            : null,
        access: json['access'] is Map
            ? Map<String, dynamic>.from(json['access'] as Map)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (profilePic != null) 'profile_pic': profilePic,
        if (gender != null) 'gender': gender,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (birthday != null) 'birthday': birthday,
        'is_verified': isVerified,
        'account_type': accountType,
        if (verificationBadge != null) 'verification_badge': verificationBadge,
        if (access != null) 'access': access,
      };

  UserProfile copyWith({
    String? name,
    String? username,
    String? email,
    String? profilePic,
    String? gender,
    String? city,
    String? country,
    String? birthday,
    bool? isVerified,
    String? accountType,
    Map<String, dynamic>? verificationBadge,
    Map<String, dynamic>? access,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        username: username ?? this.username,
        email: email ?? this.email,
        profilePic: profilePic ?? this.profilePic,
        gender: gender ?? this.gender,
        city: city ?? this.city,
        country: country ?? this.country,
        birthday: birthday ?? this.birthday,
        isVerified: isVerified ?? this.isVerified,
        accountType: accountType ?? this.accountType,
        verificationBadge: verificationBadge ?? this.verificationBadge,
        access: access ?? this.access,
      );
}

class UserNotifier extends StateNotifier<UserProfile?> {
  UserNotifier() : super(null);

  void setUser(UserProfile user) => state = user;

  void updateUser(UserProfile Function(UserProfile) update) {
    if (state != null) state = update(state!);
  }

  void clearUser() {
    state = null;
    AppStorage.remove(_kCacheKey).ignore();
  }

  /// Load cached profile from SharedPreferences synchronously so UI has data
  /// before any network request completes.
  Future<void> loadFromStorage() async {
    try {
      final raw = await AppStorage.get(_kCacheKey);
      if (raw == null) return;
      final Map<String, dynamic> json = raw is String ? jsonDecode(raw) : Map<String, dynamic>.from(raw as Map);
      state = UserProfile.fromJson(json);
      AppLogger.log('[UserNotifier] Restored profile from cache: ${state?.name}');
    } catch (e) {
      AppLogger.error('[UserNotifier] loadFromStorage error', e);
    }
  }

  /// Fetch fresh profile from API, update state and write-through cache.
  Future<void> fetchAndCache(String uid) async {
    try {
      final res = await dioClient.get('/v1/user/$uid');
      final data = res.data?['data'];
      if (data == null) return;
      final profile = UserProfile.fromJson(data as Map<String, dynamic>);
      state = profile;
      await AppStorage.set(_kCacheKey, jsonEncode(profile.toJson()));
      AppLogger.log('[UserNotifier] Profile fetched & cached: ${profile.name}');
    } catch (e) {
      AppLogger.error('[UserNotifier] fetchAndCache error', e);
    }
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile?>((ref) => UserNotifier());
