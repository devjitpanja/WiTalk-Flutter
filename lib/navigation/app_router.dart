import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/onboarding/complete_profile_screen.dart';
import '../screens/onboarding/purpose_interests_screen.dart';
import '../screens/tutorial/tutorial_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/post_detail_screen.dart';
import '../screens/home/post_view_screen.dart';
import '../screens/home/create_post_screen.dart';
import '../screens/explore/explore_screen.dart';
import '../screens/explore/search_screen.dart';
import '../screens/explore/search_result_screen.dart';
import '../screens/explore/discover_people_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/user_profile_screen.dart';

import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/followers_screen.dart';
import '../screens/profile/account_screen.dart';
import '../screens/profile/account_overview_screen.dart';
import '../screens/profile/blocked_accounts_screen.dart';
import '../screens/profile/my_purchases_screen.dart';
import '../screens/profile/rewards_screen.dart';
import '../screens/profile/pass_screen.dart';
import '../screens/profile/visitors_screen.dart';
import '../screens/profile/likes_screen.dart';
import '../screens/profile/merit_screen.dart';
import '../screens/profile/streak_screen.dart';
import '../screens/profile/wi_wallet_screen.dart';
import '../screens/profile/wallet_settings_screen.dart';
import '../screens/profile/rank_screen.dart';
import '../screens/profile/saved_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/chat_conversation_screen.dart';
import '../screens/chat/group_chat_screen.dart';
import '../screens/chat/group_list_screen.dart';
import '../screens/chat/create_group_screen.dart';
import '../screens/chat/group_info_screen.dart';
import '../screens/chat/group_permissions_screen.dart';
import '../screens/chat/group_tools_screen.dart';
import '../screens/chat/group_action_log_screen.dart';
import '../screens/chat/add_group_members_screen.dart';
import '../screens/chat/join_group_screen.dart';
import '../screens/chat/banned_users_screen.dart';
import '../screens/chat/welcome_message_screen.dart';
import '../screens/chat/start_group_adda_screen.dart';
import '../screens/chat/message_requests_screen.dart';
import '../screens/chat/pending_requests_screen.dart';
import '../screens/chat/pinned_messages_screen.dart';
import '../screens/chat/spam_protection_screen.dart';
import '../screens/chat/topics/topics_list_view.dart';
import '../screens/chat/topics/topic_detail_screen.dart';
import '../screens/channels/channel_list_screen.dart';
import '../screens/channels/channel_screen.dart';
import '../screens/channels/explore_channels_screen.dart';
import '../screens/channels/create_channel_screen.dart';
import '../screens/channels/channel_info_screen.dart';
import '../screens/channels/edit_channel_screen.dart';
import '../screens/channels/channel_subscribers_screen.dart';
import '../screens/channels/channel_admins_screen.dart';
import '../screens/channels/channel_banned_users_screen.dart';
import '../screens/connect/adda_screen.dart';
import '../screens/connect/live_audio_room_screen.dart';
import '../screens/connect/create_audio_room_screen.dart';
import '../screens/connect/nearby_people_screen.dart';
import '../screens/connect/discover_all_screen.dart';
import '../screens/connect/city_screen.dart';
import '../screens/connect/explore_communities_screen.dart';
import '../screens/connect/for_you_screen.dart';
import '../screens/connect/for_you_tab.dart';
import '../screens/connect/activities_screen.dart';
import '../screens/connect/community_info_screen.dart';
import '../screens/connect/community_adda_list_screen.dart';
import '../screens/connect/adda_reviews_screen.dart';
import '../screens/connect/adda_feedback.dart';
import '../screens/onboarding/location_permission_screen.dart';
import '../screens/calls/video_call_screen.dart';
import '../screens/calls/voice_call_screen.dart';
import '../screens/calls/random_chat_screen.dart';
import '../screens/missions/missions_screen.dart';
import '../screens/missions/referral_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/message_privacy_screen.dart';
import '../screens/settings/content_preferences_screen.dart';
import '../screens/settings/storage_data_screen.dart';
import '../screens/settings/bugs_suggestions_screen.dart';
import '../screens/media/camera_screen.dart';
import '../screens/media/fullscreen_video_screen.dart';
import '../screens/media/mini_screen.dart';
import '../screens/home/report_screen.dart';
import '../screens/profile/id_verification_screen.dart';
import '../screens/profile/write_review_screen.dart';
import '../screens/profile/ranking_rules_screen.dart';
import '../screens/splash/splash_screen.dart';
import 'shell_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final locationPerm = ref.watch(locationPermissionProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isUnknown = authState.status == AuthStatus.unknown;
      final onSplash = state.matchedLocation == '/splash';
      final onAuthPage = state.matchedLocation.startsWith('/auth');
      final onLocPerm = state.matchedLocation == '/location-permission';
      final onOnboarding = state.matchedLocation.startsWith('/complete-profile') ||
          state.matchedLocation.startsWith('/purpose-interests') ||
          state.matchedLocation.startsWith('/tutorial');

      if (isUnknown) return onSplash ? null : '/splash';
      if (!isAuth && !onAuthPage) return '/auth';
      if (isAuth && (onAuthPage || onSplash)) {
        // After login or app restore: show location permission screen if needed
        if (!locationPerm.granted && !locationPerm.hasSeenScreen) {
          return '/location-permission';
        }
        return '/home';
      }
      // When landing on /home for the first time after onboarding (not already on loc perm page)
      if (isAuth && state.matchedLocation == '/home' && !onLocPerm && !onOnboarding) {
        if (!locationPerm.granted && !locationPerm.hasSeenScreen) {
          return '/location-permission';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/complete-profile', builder: (_, __) => const CompleteProfileScreen()),
      GoRoute(path: '/purpose-interests', builder: (_, __) => const PurposeInterestsScreen()),
      GoRoute(path: '/tutorial', builder: (_, __) => const TutorialScreen()),
      GoRoute(path: '/location-permission', builder: (_, __) => const LocationPermissionScreen()),

      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
          GoRoute(path: '/adda', builder: (_, __) => const AddaScreen()),
          GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          GoRoute(path: '/account', builder: (_, __) => const AccountOverviewScreen()),
        ],
      ),

      // Posts
      GoRoute(path: '/post/:id', builder: (_, s) => PostDetailScreen(postId: s.pathParameters['id']!)),
      GoRoute(
        path: '/post-view/:suffix',
        builder: (_, s) => PostViewScreen(
          suffix: s.pathParameters['suffix']!,
          highlightCommentId: s.uri.queryParameters['commentId'],
        ),
      ),
      GoRoute(
        path: '/create-post',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CreatePostScreen(
            isEditing: extra['isEditing'] as bool? ?? false,
            postId: extra['postId'] as String?,
            initialContent: extra['initialContent'] as String?,
            capturedMedia: (extra['capturedMedia'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList(),
            fromCamera: extra['fromCamera'] as bool? ?? false,
            thoughtsMode: extra['thoughtsMode'] as bool? ?? false,
          );
        },
      ),

      // Explore
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/search-result', builder: (_, s) => SearchResultScreen(query: s.uri.queryParameters['q'] ?? '')),
      GoRoute(path: '/discover-people', builder: (_, __) => const DiscoverPeopleScreen()),

      // Profile
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/profile/:id', builder: (_, s) => UserProfileScreen(userId: s.pathParameters['id']!)),
      GoRoute(path: '/user/:id', builder: (_, s) => UserProfileScreen(userId: s.pathParameters['id']!)),
      GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/followers/:id', builder: (_, s) => FollowersScreen(userId: s.pathParameters['id']!)),
      GoRoute(path: '/account-overview', builder: (_, __) => const AccountOverviewScreen()),
      GoRoute(path: '/account-settings', builder: (_, __) => const AccountScreen()),
      GoRoute(path: '/purchases', builder: (_, __) => const MyPurchasesScreen()),
      GoRoute(path: '/rewards', builder: (_, __) => const RewardsScreen()),
      GoRoute(path: '/pass', builder: (_, __) => const PassScreen()),
      GoRoute(path: '/blocked-accounts', builder: (_, __) => const BlockedAccountsScreen()),
      GoRoute(path: '/visitors', builder: (_, __) => const VisitorsScreen()),
      GoRoute(path: '/likes', builder: (_, __) => const LikesScreen()),
      GoRoute(path: '/merit', builder: (_, __) => const MeritScreen()),
      GoRoute(path: '/streak', builder: (_, __) => const StreakScreen()),
      GoRoute(path: '/wallet', builder: (_, __) => const WiWalletScreen()),
      GoRoute(path: '/wallet-settings', builder: (_, __) => const WalletSettingsScreen()),
      GoRoute(path: '/rank', builder: (_, __) => const RankScreen()),
      GoRoute(path: '/ranking-rules', builder: (_, __) => const RankingRulesScreen()),
      GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
      GoRoute(path: '/id-verification', builder: (_, __) => const IdVerificationScreen()),

      // Chat — Private
      GoRoute(
        path: '/chat/conversation/:id',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return ChatConversationScreen(
            chatId: s.pathParameters['id']!,
            otherUser: extra?['otherUser'] as Map<String, dynamic>?,
            conversationStatus: extra?['status'] as String?,
            initiatorId: extra?['initiatorId'] as String?,
          );
        },
      ),
      GoRoute(path: '/chat/requests', builder: (_, __) => const MessageRequestsScreen()),
      GoRoute(path: '/chat/pending-requests', builder: (_, __) => const PendingRequestsScreen()),
      GoRoute(path: '/chat/pinned/:id', builder: (_, s) => PinnedMessagesScreen(conversationId: s.pathParameters['id']!, isGroup: false)),

      // Chat — Groups
      GoRoute(path: '/chat/group/:id', builder: (_, s) => GroupChatScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/groups', builder: (_, __) => const GroupListScreen()),
      GoRoute(path: '/chat/create-group', builder: (_, __) => const CreateGroupScreen()),
      GoRoute(path: '/chat/join-group', builder: (_, __) => const JoinGroupScreen()),
      GoRoute(path: '/chat/group-info/:id', builder: (_, s) => GroupInfoScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/group-permissions/:id', builder: (_, s) => GroupPermissionsScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/group-tools/:id', builder: (_, s) => GroupToolsScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/group-action-log/:id', builder: (_, s) => GroupActionLogScreen(groupId: s.pathParameters['id']!)),
      GoRoute(
        path: '/chat/add-group-members/:id',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return AddGroupMembersScreen(
            groupId: s.pathParameters['id']!,
            existingMemberIds: (extra?['existingMemberIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
          );
        },
      ),
      GoRoute(path: '/chat/banned-users/:id', builder: (_, s) => BannedUsersScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/welcome-message/:id', builder: (_, s) => WelcomeMessageScreen(groupId: s.pathParameters['id']!)),
      GoRoute(
        path: '/chat/start-adda/:id',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return StartGroupAddaScreen(
            groupId: s.pathParameters['id']!,
            groupName: extra?['groupName'] as String? ?? 'Group',
          );
        },
      ),
      GoRoute(path: '/chat/spam-protection/:id', builder: (_, s) => SpamProtectionScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/group-spam-protection/:id', builder: (_, s) => SpamProtectionScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/chat/group-pinned/:id', builder: (_, s) => PinnedMessagesScreen(conversationId: s.pathParameters['id']!, isGroup: true)),

      // Chat — Topics
      GoRoute(
        path: '/chat/group-topics/:id',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return TopicsListView(
            groupId: s.pathParameters['id']!,
            isAdmin: extra?['isAdmin'] == true,
          );
        },
      ),
      GoRoute(
        path: '/chat/group-topics/:groupId/:topicId',
        builder: (_, s) => TopicDetailScreen(
            groupId: s.pathParameters['groupId']!,
            topicId: s.pathParameters['topicId']!),
      ),

      // Channels
      GoRoute(path: '/channels', builder: (_, __) => const ChannelListScreen()),
      GoRoute(
        path: '/channel/:id',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return ChannelScreen(
            channelId: s.pathParameters['id']!,
            initialChannel: extra?['channel'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(path: '/explore-channels', builder: (_, __) => const ExploreChannelsScreen()),
      GoRoute(path: '/create-channel', builder: (_, __) => const CreateChannelScreen()),
      GoRoute(path: '/channel-info/:id', builder: (_, s) => ChannelInfoScreen(channelId: s.pathParameters['id']!)),
      GoRoute(
        path: '/edit-channel/:id',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return EditChannelScreen(
            channelId: s.pathParameters['id']!,
            initialChannel: extra?['channel'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(
        path: '/channel-subscribers/:id',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return ChannelSubscribersScreen(
            channelId: s.pathParameters['id']!,
            initialSubscriberCount: (extra?['subscriberCount'] as num?)?.toInt() ?? 0,
            isOwner: extra?['isOwner'] == true,
            isAdmin: extra?['isAdmin'] == true,
          );
        },
      ),
      GoRoute(
        path: '/channel-admins/:id',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return ChannelAdminsScreen(
            channelId: s.pathParameters['id']!,
            isOwner: extra?['isOwner'] == true,
          );
        },
      ),
      GoRoute(path: '/channel-banned-users/:id', builder: (_, s) => ChannelBannedUsersScreen(channelId: s.pathParameters['id']!)),

      // Connect
      GoRoute(path: '/live-audio/:id', builder: (_, s) => LiveAudioRoomScreen(roomId: s.pathParameters['id']!)),
      GoRoute(path: '/create-audio-room', builder: (_, __) => const CreateAudioRoomScreen()),
      GoRoute(path: '/community-adda-list/:id', builder: (_, s) => CommunityAddaListScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/adda-reviews', builder: (_, __) => const AddaReviewsScreen()),
      GoRoute(path: '/adda-feedback', builder: (_, __) => const AddaFeedbackScreen()),
      GoRoute(path: '/nearby-people', builder: (_, __) => const NearbyPeopleScreen()),
      GoRoute(
        path: '/discover-all',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final users = (extra['users'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          final me = extra['me'] as Map<String, dynamic>?;
          return DiscoverAllScreen(users: users, me: me);
        },
      ),
      GoRoute(path: '/city/:id', builder: (_, s) => CityScreen(cityId: s.pathParameters['id']!)),
      GoRoute(path: '/communities', builder: (_, __) => const ExploreCommunitiesScreen()),
      GoRoute(path: '/for-you', builder: (_, __) => const ForYouScreen()),
      GoRoute(path: '/community-info/:id', builder: (_, s) => CommunityInfoScreen(communityId: s.pathParameters['id']!)),

      // Calls
      GoRoute(path: '/video-call/:id', builder: (_, s) => VideoCallScreen(roomId: s.pathParameters['id']!)),
      GoRoute(path: '/voice-call/:id', builder: (_, s) => VoiceCallScreen(roomId: s.pathParameters['id']!)),
      GoRoute(path: '/random-chat', builder: (_, __) => const RandomChatScreen()),

      // Missions & Referral
      GoRoute(path: '/missions', builder: (_, __) => const MissionsScreen()),
      GoRoute(path: '/referral', builder: (_, __) => const ReferralScreen()),

      // Notifications
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationScreen()),

      // Settings
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/settings/notifications', builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(path: '/settings/message-privacy', builder: (_, __) => const MessagePrivacyScreen()),
      GoRoute(path: '/settings/content', builder: (_, __) => const ContentPreferencesScreen()),
      GoRoute(path: '/settings/storage', builder: (_, __) => const StorageDataScreen()),
      GoRoute(path: '/bugs-suggestions', builder: (_, __) => const BugsSuggestionsScreen()),

      // Media
      GoRoute(
        path: '/camera',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final mode = extra['initialMode'] as String? ?? state.uri.queryParameters['mode'];
          return CameraScreen(initialMode: mode);
        },
      ),
      GoRoute(path: '/fullscreen-video', builder: (_, s) => FullscreenVideoScreen(url: s.uri.queryParameters['url'] ?? '')),
      GoRoute(
        path: '/mini',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final posts = (extra['posts'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              const <Map<String, dynamic>>[];
          return MiniScreen(
            initialPosts: posts,
            initialIndex: (extra['initialIndex'] as int?) ?? 0,
            currentUserId: extra['userId'] as String?,
            fromVideoClick: extra['fromVideoClick'] == true,
          );
        },
      ),

      // Utility
      GoRoute(path: '/report/:type/:id', builder: (_, s) => ReportScreen(targetType: s.pathParameters['type']!, targetId: s.pathParameters['id']!)),
      GoRoute(path: '/write-review/:id', builder: (_, s) => WriteReviewScreen(targetId: s.pathParameters['id']!)),
    ],
  );
});
