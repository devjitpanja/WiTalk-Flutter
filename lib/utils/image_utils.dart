/// Returns the best profile image URL for a user map.
/// Prefers the 600px medium variant to save bandwidth; falls back to original.
///
/// [size]: 'medium' (default) for list/avatar contexts, 'full' for profile screen.
String? getProfileImageUrl(Map<String, dynamic>? user, {String size = 'medium'}) {
  if (user == null) return null;
  if (size == 'full') return user['profile_pic'] as String?;
  return (user['profile_pic_medium'] as String?) ?? (user['profile_pic'] as String?);
}

/// Same as [getProfileImageUrl] but accepts a bare URL string.
/// Use when you only have the URL, not the full user object.
String? getProfileImageUrlFromString(String? profilePicUrl) => profilePicUrl;
