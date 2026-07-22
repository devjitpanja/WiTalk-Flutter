import 'package:dio/dio.dart';
import 'dio_client.dart';

bool isValidGlobalHandle(String? handle) {
  final h = (handle ?? '').toLowerCase().trim();
  return RegExp(r'^[a-z0-9_-]{3,30}$').hasMatch(h);
}

class ChannelApi {
  static const String base = '/v1/channels';

  // Discovery
  static Future<Response> getFeatured() => dioClient.get('$base/featured');

  static Future<Response> create(Map<String, dynamic> data) =>
      dioClient.post('$base/create', data: data);

  static Future<Response> checkUsername(String username) =>
      dioClient.get('$base/check-username/${Uri.encodeComponent(username)}');

  static Future<Response> getPublic({int limit = 40, int offset = 0, String? search}) {
    final Map<String, dynamic> params = {'limit': limit, 'offset': offset};
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    return dioClient.get('$base/public', queryParameters: params);
  }

  static Future<Response> getMy() => dioClient.get('$base/my');

  static Future<Response> getById(String channelId) => dioClient.get('$base/$channelId');

  static Future<Response?> getByUsername(String username) async {
    if (!isValidGlobalHandle(username)) {
      return null;
    }
    return dioClient.get('/v1/username/resolve/${Uri.encodeComponent(username)}');
  }

  static Future<Response> getByInviteCode(String code) =>
      dioClient.get('$base/invite/$code');

  static Future<Response> update(String channelId, Map<String, dynamic> data) =>
      dioClient.put('$base/$channelId', data: data);

  static Future<Response> deleteChannel(String channelId) =>
      dioClient.delete('$base/$channelId');

  static Future<Response> revokeLink(String channelId) =>
      dioClient.post('$base/$channelId/revoke-link');

  // Subscription
  static Future<Response> subscribe(String channelId) =>
      dioClient.post('$base/$channelId/subscribe');

  static Future<Response> unsubscribe(String channelId) =>
      dioClient.delete('$base/$channelId/subscribe');

  static Future<Response> mute(String channelId) =>
      dioClient.post('$base/$channelId/mute');

  static Future<Response> unmute(String channelId) =>
      dioClient.delete('$base/$channelId/mute');

  // Messages
  static Future<Response> getMessages(String channelId, {Map<String, dynamic>? params}) =>
      dioClient.get('$base/$channelId/messages', queryParameters: params);

  static Future<Response> getMessagesAround(String channelId, String messageId) =>
      dioClient.get('$base/$channelId/messages', queryParameters: {'around': messageId});

  static Future<Response> sendMessage(String channelId, Map<String, dynamic> data) =>
      dioClient.post('$base/$channelId/messages', data: data);

  static Future<Response> editMessage(String channelId, String messageId, String content) =>
      dioClient.patch('$base/$channelId/messages/$messageId', data: {'content': content});

  static Future<Response> deleteMessage(String channelId, String messageId) =>
      dioClient.delete('$base/$channelId/messages/$messageId');

  // Reactions
  static Future<Response> react(String channelId, String messageId, String emoji) =>
      dioClient.post('$base/$channelId/messages/$messageId/react', data: {'emoji': emoji});

  // Pins
  static Future<Response> getPinnedMessages(String channelId) =>
      dioClient.get('$base/$channelId/pinned');

  static Future<Response> pinMessage(String channelId, String messageId) =>
      dioClient.post('$base/$channelId/messages/$messageId/pin');

  static Future<Response> unpinMessage(String channelId, String messageId) =>
      dioClient.delete('$base/$channelId/messages/$messageId/pin');

  // Reports
  static Future<Response> reportMessage(
          String channelId, String messageId, String category, String? description) =>
      dioClient.post('$base/$channelId/messages/$messageId/report',
          data: {'category': category, 'description': description});

  static Future<Response> reportChannel(
          String channelId, String category, String? description) =>
      dioClient.post('/v1/report', data: {
        'reported_entity_type': 'channel',
        'reported_entity_id': channelId,
        'report_category': category,
        'description': description,
        'report_source': 'channel_info',
      });

  // Admins
  static Future<Response> getAdmins(String channelId) =>
      dioClient.get('$base/$channelId/admins');

  static Future<Response> addAdmin(String channelId, String targetUserId) =>
      dioClient.post('$base/$channelId/admins', data: {'targetUserId': targetUserId});

  static Future<Response> removeAdmin(String channelId, String targetUserId) =>
      dioClient.delete('$base/$channelId/admins/$targetUserId');

  // Subscribers
  static Future<Response> getSubscribers(String channelId, {Map<String, dynamic>? params}) =>
      dioClient.get('$base/$channelId/subscribers', queryParameters: params);

  static Future<Response> kickSubscriber(String channelId, String targetUserId) =>
      dioClient.delete('$base/$channelId/subscribers/$targetUserId');

  static Future<Response> banSubscriber(
          String channelId, String targetUserId, String? reason) =>
      dioClient.post('$base/$channelId/subscribers/$targetUserId/ban',
          data: {'reason': reason});

  static Future<Response> makeSubscriberAdmin(String channelId, String targetUserId) =>
      dioClient.post('$base/$channelId/subscribers/$targetUserId/make-admin');

  // Bans
  static Future<Response> getBannedUsers(String channelId, {Map<String, dynamic>? params}) =>
      dioClient.get('$base/$channelId/bans', queryParameters: params);

  static Future<Response> unbanUser(String channelId, String targetUserId) =>
      dioClient.delete('$base/$channelId/bans/$targetUserId');

  // View & Read Tracking
  static Future<Response> trackViews(String channelId, List<String> messageIds) =>
      dioClient.post('$base/$channelId/messages/views', data: {'message_ids': messageIds});

  static Future<Response> markRead(String channelId, String lastMessageId) =>
      dioClient.post('$base/$channelId/mark-read', data: {'last_message_id': lastMessageId});

  // Polls
  static Future<Response> votePoll(
          String channelId, String messageId, List<int> optionIndices) =>
      dioClient.post('$base/$channelId/messages/$messageId/poll/vote',
          data: {'option_indices': optionIndices});

  static Future<Response> retractVote(String channelId, String messageId) =>
      dioClient.delete('$base/$channelId/messages/$messageId/poll/vote');

  static Future<Response> getPollResults(String channelId, String messageId) =>
      dioClient.get('$base/$channelId/messages/$messageId/poll');

  static Future<Response> getPollVoters(String channelId, String messageId) =>
      dioClient.get('$base/$channelId/messages/$messageId/poll/voters');

  // Media & Links
  static Future<Response> getMedia(String channelId, {Map<String, dynamic>? params}) =>
      dioClient.get('$base/$channelId/media', queryParameters: params);

  static Future<Response> getLinks(String channelId, {Map<String, dynamic>? params}) =>
      dioClient.get('$base/$channelId/links', queryParameters: params);
}
