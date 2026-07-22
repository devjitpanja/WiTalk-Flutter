import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'logger.dart';

export 'time_utils.dart' show formatTimeAgo;

void navigateToUserProfile(BuildContext context, String userId, [String? username]) {
  if (userId.isEmpty) {
    AppLogger.error('userId is required');
    return;
  }
  Navigator.of(context).pushNamed('/user-profile', arguments: {'userId': userId, 'username': username});
}

void navigateToOwnProfile(BuildContext context) {
  Navigator.of(context).pushNamed('/profile');
}

Map<String, String> generateProfileShareUrl(String username) {
  final identifier = username.isNotEmpty ? username : 'user';
  return {
    'appUrl': 'witalk://user/$identifier',
    'webUrl': 'https://witalk.in/user/$identifier',
    'shareText': 'Check out this profile on WiTalk!',
  };
}

Future<void> shareProfile(Map<String, dynamic> profileData) async {
  try {
    final username = profileData['username'] as String? ?? profileData['id'] as String? ?? '';
    final urls = generateProfileShareUrl(username);
    final name = profileData['name'] as String? ?? 'Someone';
    await SharePlus.instance.share(
      ShareParams(text: '${urls['shareText']} ${urls['webUrl']}', subject: '$name - WiTalk Profile'),
    );
  } catch (e) {
    AppLogger.error('Error sharing profile', e);
  }
}

String formatUserStatCount(num? count) {
  if (count == null || count == 0) return '0';
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toInt().toString();
}

bool isOwnProfile(String? currentUserId, String? profileUserId) =>
    profileUserId == null || profileUserId == currentUserId;

Map<String, dynamic> parseProfileRouteParams(Map<String, dynamic>? routeParams) => {
  'targetUserId': routeParams?['userId'],
  'username': routeParams?['username'],
  'shouldRefresh': routeParams?['refreshProfile'],
  'identifier': routeParams?['username'] ?? routeParams?['userId'],
};

List<dynamic> _parseJsonArray(dynamic value) {
  if (value is List) return value;
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } catch (_) {}
  }
  return [];
}

Map<String, dynamic>? validateProfileData(Map<String, dynamic>? profileData) {
  if (profileData == null) return null;
  return {
    'id': profileData['id'] ?? '',
    'name': profileData['name'] ?? 'Unknown User',
    'username': profileData['username'] ?? profileData['id'] ?? '',
    'profile_pic': profileData['profile_pic'],
    'photos': _parseJsonArray(profileData['photos']),
    'bio': profileData['bio'] ?? '',
    'followers_count': profileData['followers_count'] ?? 0,
    'following_count': profileData['following_count'] ?? 0,
    'friends_count': profileData['friends_count'] ?? 0,
    'email': profileData['email'] ?? '',
    'created_at': profileData['created_at'] ?? '',
    'address': profileData['address'] ?? '',
    'gender': profileData['gender'] ?? '',
    'country': profileData['country'] ?? '',
    'countryCode': profileData['countryCode'] ?? '',
    'interests': _parseJsonArray(profileData['interests']),
    'purpose': _parseJsonArray(profileData['purpose']),
    'birthday': profileData['birthday'] ?? '',
    'occupation': profileData['occupation'] ?? '',
    'school': profileData['school'] ?? '',
    'city': profileData['city'] ?? '',
    'region': profileData['region'] ?? '',
    'is_verified': profileData['is_verified'] ?? false,
    'verification_badge': profileData['verification_badge'],
    'privacy_settings': profileData['privacy_settings'],
    'avatar_frame': profileData['avatar_frame'],
  };
}

String handleProfileAPIError(Object error, [String operation = 'load profile']) {
  AppLogger.error('Profile API Error ($operation)', error);
  final msg = error.toString();
  if (msg.contains('404')) return operation.contains('profile') ? 'Profile not found' : 'Failed to $operation';
  if (msg.contains('403')) return 'You do not have permission to perform this action';
  if (msg.contains('401')) return 'Please log in to continue';
  if (msg.contains('429')) return 'Too many requests. Please try again later';
  if (msg.contains('500')) return 'Server error. Please try again later';
  return 'Failed to $operation';
}

bool canFollowUser(String? currentUserId, String? targetUserId) =>
    currentUserId != null && targetUserId != null && currentUserId != targetUserId;

String getFollowButtonText(bool isFollowing, {bool isLoading = false}) {
  if (isLoading) return isFollowing ? 'Unfollowing...' : 'Following...';
  return isFollowing ? 'Following' : 'Follow';
}

Map<String, dynamic> checkProfileCompleteness(Map<String, dynamic>? profileData) {
  if (profileData == null) return {'isComplete': false, 'missingFields': ['all']};

  const required = ['name', 'username', 'profile_pic'];
  const optional = ['bio', 'address'];

  final missingRequired = required
      .where((f) => profileData[f] == null || profileData[f].toString().isEmpty)
      .toList();
  final missingOptional = optional
      .where((f) => profileData[f] == null || profileData[f].toString().isEmpty)
      .toList();

  final completionPct = (((required.length + optional.length) -
              missingRequired.length -
              missingOptional.length) /
          (required.length + optional.length) *
          100)
      .round();

  return {
    'isComplete': missingRequired.isEmpty,
    'completionPercentage': completionPct,
    'missingRequired': missingRequired,
    'missingOptional': missingOptional,
    'hasBasicInfo': missingRequired.isEmpty,
  };
}

String? extractUserId(Map<String, dynamic>? user, [String? userIdProp]) =>
    user?['id'] as String? ??
    user?['user_id'] as String? ??
    user?['uid'] as String? ??
    userIdProp;
