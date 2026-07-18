import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

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
      );

  UserProfile copyWith({
    String? name, String? username, String? email, String? profilePic,
    String? gender, String? city, String? country, String? birthday, bool? isVerified,
  }) => UserProfile(
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
      );
}

class UserNotifier extends StateNotifier<UserProfile?> {
  UserNotifier() : super(null);

  void setUser(UserProfile user) => state = user;
  void updateUser(UserProfile Function(UserProfile) update) {
    if (state != null) state = update(state!);
  }
  void clearUser() => state = null;
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile?>((ref) => UserNotifier());
