import '../config/app_config.dart';

class AppEndpoints {
  // Auth
  static const String login = '/v1/user/create';
  static const String loginStatus = '/v1/user/{uid}/login-status';
  static const String refreshToken = '/v1/auth/refresh';

  // User
  static const String userProfile = '/v1/user/{uid}';
  static const String updateProfile = '/v1/user/{uid}/profile';
  static const String checkUsername = '/v1/user/check-username';

  // Upload
  static String get uploadSingle => '${AppConfig.filesApiUrl.replaceAll(AppConfig.apiBaseUrl, '')}';
  static const String uploadProfilePic = '/v1/upload/profile-pic';

  // Posts
  static const String feed = '/v1/posts/feed';
  static const String miniFeed = '/v1/posts/mini-feed';
  static const String createPost = '/v1/posts';
  static String postDetail(String id) => '/v1/posts/$id';
  static String postComments(String id) => '/v1/posts/$id/comments';
  static String likePost(String id) => '/v1/posts/$id/like';

  // Chat
  static const String conversations = '/v1/chat/conversations';
  static const String contacts = '/v1/chat/contacts';
  static const String requests = '/v1/chat/requests';
  static String chatMessages(String id) => '/v1/chat/$id/messages';
  static String chatInfo(String id) => '/v1/chat/$id/info';

  // Groups
  static const String groups = '/v1/chat/groups';
  static const String createGroup = '/v1/groups/create';
  static String groupMessages(String id) => '/v1/groups/$id/messages';
  static String groupDetail(String id) => '/v1/groups/$id';
  static String leaveGroup(String id) => '/v1/groups/$id/leave';

  // Channels
  static const String myChannels = '/v1/channels/my';
  static const String exploreChannels = '/v1/channels/explore';
  static const String createChannel = '/v1/channels/create';
  static String channelMessages(String id) => '/v1/channels/$id/messages';

  // Audio Rooms
  static const String audioRooms = '/v1/audio-rooms';
  static const String createAudioRoom = '/v1/audio-rooms/create';
  static String joinAudioRoom(String id) => '/v1/audio-rooms/$id/join';

  // Notifications
  static const String notifications = '/v1/notifications';
  static const String registerPushToken = '/v1/fcm/token/register';

  // Missions
  static const String missions = '/v1/missions';

  // Explore
  static const String peopleSuggestions = '/v1/followers/suggestions';
  static const String popularHashtags = '/v1/hashtags/popular';
  static const String publicGroups = '/v1/groups/public/list';
  static const String discoverForYou = '/v1/discover/for-you';
  static const String discoverPeople = '/v1/users/discover';
  static const String nearbyPeople = '/v1/nearby';
}
