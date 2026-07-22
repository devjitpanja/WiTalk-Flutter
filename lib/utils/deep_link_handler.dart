import 'package:url_launcher/url_launcher.dart';
import 'logger.dart';

const _witalkDomains = ['witalk.in', 'www.witalk.in'];
const _witalkScheme = 'witalk://';

bool isWiTalkDeepLink(String? url) {
  if (url == null || url.isEmpty) return false;
  try {
    if (url.startsWith(_witalkScheme)) return true;
    final uri = Uri.parse(url);
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return _witalkDomains.contains(uri.host);
    }
    return false;
  } catch (_) {
    return false;
  }
}

String? extractDeepLinkPath(String url) {
  try {
    if (url.startsWith(_witalkScheme)) {
      final path = url.substring(_witalkScheme.length);
      return path.replaceAll(RegExp(r'^/|/$'), '');
    }
    final uri = Uri.parse(url);
    return uri.path.replaceAll(RegExp(r'^/|/$'), '');
  } catch (e) {
    DeepLinkLogger.error('Error extracting deep link path', e);
    return null;
  }
}

const _systemPaths = {
  'home', 'search', 'chats', 'notifications', 'profile',
  'auth', 'complete-profile', 'purpose-interests',
  'create-post', 'saved', 'missions', 'rank', 'match',
  'edit-profile', 'visitors', 'likes',
};

const _tabScreens = {
  'home': 'Home', 'search': 'Search', 'chats': 'Chats',
  'notifications': 'Notifications', 'profile': 'Profile',
};

const _simpleScreens = {
  'create-post': 'CreatePost', 'edit-profile': 'EditProfile',
  'account-overview': 'AccountOverview', 'visitors': 'Visitors',
  'likes': 'Likes', 'saved': 'Saved', 'missions': 'Missions',
  'rank': 'Rank', 'ranking-rules': 'RankingRules', 'match': 'Match',
  'match-details': 'MatchDetails', 'id-verification': 'IdVerification',
  'settings/notifications': 'NotificationSettings',
  'settings/content': 'ContentPreferences',
  'search-result': 'SearchResult', 'report': 'Report',
  'feedback': 'Feedback', 'bugs-suggestions': 'BugsAndSuggestions',
  'report-bug': 'ReportBug', 'make-suggestion': 'MakeSuggestion',
  'menu/missions': 'Missions', 'menu/rank': 'Rank',
  'menu/ranking-rules': 'RankingRules', 'menu/tutorial': 'Tutorial',
  'menu/rewards': 'ContributorRewards', 'menu/privacy': 'MessagePrivacy',
  'menu/referral': 'Referral', 'menu/wallet': 'WiWallet',
  'menu/streak': 'Streak', 'menu/merit': 'Merit', 'menu/account': 'Account',
};

class DeepLinkInfo {
  final String type;
  final Map<String, String> params;
  final bool isComplex;
  final String? screen;

  const DeepLinkInfo({
    required this.type,
    required this.params,
    required this.isComplex,
    this.screen,
  });
}

DeepLinkInfo getDeepLinkType(String? path) {
  if (path == null || path.isEmpty) {
    return const DeepLinkInfo(type: 'home', params: {}, isComplex: false);
  }

  if (path.startsWith('p/')) {
    return DeepLinkInfo(type: 'post', params: {'suffix': path.substring(2)}, isComplex: false, screen: 'PostView');
  }
  if (path.startsWith('post/')) {
    return DeepLinkInfo(type: 'postDetail', params: {'postId': path.substring(5)}, isComplex: false, screen: 'PostDetail');
  }
  if (path.startsWith('m/')) {
    return DeepLinkInfo(type: 'message', params: {'username': path.substring(2)}, isComplex: true);
  }
  if (path.startsWith('adda/')) {
    return DeepLinkInfo(type: 'adda', params: {'room_id': path.substring(5)}, isComplex: true);
  }
  if (path.startsWith('group/')) {
    return DeepLinkInfo(type: 'groupInvite', params: {'inviteCode': path.substring(6)}, isComplex: true);
  }
  if (path.startsWith('groupchat/')) {
    return DeepLinkInfo(type: 'groupChat', params: {'groupId': path.substring(10)}, isComplex: false, screen: 'GroupChat');
  }
  if (path.startsWith('system/')) {
    final systemType = path.substring(7);
    final screenMap = {'voice-call': 'VoiceCall', 'video-call': 'VideoCall', 'random-chat': 'RandomChat'};
    final typeMap = {'voice-call': 'voiceCall', 'video-call': 'videoCall', 'random-chat': 'randomChat'};
    if (screenMap.containsKey(systemType)) {
      return DeepLinkInfo(type: typeMap[systemType]!, params: {}, isComplex: false, screen: screenMap[systemType]);
    }
  }
  if (path.startsWith('video/')) {
    return DeepLinkInfo(type: 'video', params: {'videoId': path.substring(6)}, isComplex: false, screen: 'FullscreenVideo');
  }
  if (path.startsWith('mini/')) {
    return DeepLinkInfo(type: 'miniViewer', params: {'videoId': path.substring(5)}, isComplex: false, screen: 'MiniViewer');
  }
  if (path.startsWith('user/')) {
    return DeepLinkInfo(type: 'userProfile', params: {'username': path.substring(5)}, isComplex: false, screen: 'UserProfile');
  }
  if (path.startsWith('group-info/')) {
    return DeepLinkInfo(type: 'groupInfo', params: {'groupId': path.substring(11)}, isComplex: false, screen: 'GroupInfo');
  }
  if (path.startsWith('followers/')) {
    return DeepLinkInfo(type: 'followers', params: {'userId': path.substring(10)}, isComplex: false, screen: 'Followers');
  }
  if (path.startsWith('about/')) {
    return DeepLinkInfo(type: 'about', params: {'username': path.substring(6)}, isComplex: false, screen: 'AboutAccount');
  }
  if (!path.contains('/') && !_systemPaths.contains(path)) {
    return DeepLinkInfo(type: 'profile', params: {'username': path}, isComplex: true);
  }
  if (_tabScreens.containsKey(path)) {
    return DeepLinkInfo(type: 'tab', params: {'screen': _tabScreens[path]!}, isComplex: false, screen: 'Tabs');
  }
  if (_simpleScreens.containsKey(path)) {
    return DeepLinkInfo(type: 'simple', params: {}, isComplex: false, screen: _simpleScreens[path]);
  }

  DeepLinkLogger.log('Unknown deep link path: $path');
  return const DeepLinkInfo(type: 'unknown', params: {}, isComplex: false);
}

Future<Map<String, dynamic>> handleWiTalkDeepLink(String url) async {
  if (!isWiTalkDeepLink(url)) {
    return {'handled': false, 'linkInfo': null, 'url': url};
  }
  try {
    final path = extractDeepLinkPath(url);
    final linkInfo = getDeepLinkType(path);

    DeepLinkLogger.separator('Handling WiTalk Deep Link');
    DeepLinkLogger.log('URL: $url');
    DeepLinkLogger.log('Path: $path');
    DeepLinkLogger.log('Type: ${linkInfo.type}');
    DeepLinkLogger.log('Is Complex: ${linkInfo.isComplex}');
    DeepLinkLogger.separator();

    if (linkInfo.isComplex) {
      return {'handled': false, 'linkInfo': linkInfo, 'url': url};
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return {'handled': true, 'linkInfo': linkInfo, 'url': url};
    }
    return {'handled': false, 'linkInfo': linkInfo, 'url': url};
  } catch (e) {
    DeepLinkLogger.error('Error handling WiTalk deep link', e);
    return {'handled': false, 'linkInfo': null, 'url': url};
  }
}

String getDeepLinkDescription(String url) {
  if (!isWiTalkDeepLink(url)) return 'External link';
  final path = extractDeepLinkPath(url);
  final linkInfo = getDeepLinkType(path);
  const descriptions = {
    'post': 'View post', 'postDetail': 'View post details',
    'message': 'Open conversation', 'adda': 'Join adda',
    'groupInvite': 'Join group', 'groupChat': 'Open group chat',
    'voiceCall': 'Start voice call', 'videoCall': 'Start video call',
    'randomChat': 'Start random chat', 'video': 'Watch video',
    'miniViewer': 'Watch video', 'userProfile': 'View profile',
    'profile': 'View profile', 'groupInfo': 'View group info',
    'followers': 'View followers', 'about': 'About account',
    'tab': 'Navigate to tab', 'simple': 'Open screen', 'unknown': 'Open link',
  };
  return descriptions[linkInfo.type] ?? 'Open in app';
}
