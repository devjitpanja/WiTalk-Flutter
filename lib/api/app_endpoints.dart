import '../config/app_config.dart';

class AppEndpoints {
  // ── Auth ──────────────────────────────────────────────────────────────
  static const String createUser = '/v1/user/create';
  static const String generateTokens = '/v1/auth/generate-tokens';
  static const String refreshToken = '/v1/auth/refresh';
  static String loginStatus(String uid) => '/v1/user/$uid/login-status';

  // ── User ──────────────────────────────────────────────────────────────
  static String userProfile(String uid) => '/v1/user/$uid';
  static String updateProfile(String uid) => '/v1/user/$uid/profile';
  static const String checkUsername = '/v1/user/check-username';
  static String findByUsername(String username) => '/v1/user/find/$username';
  static const String supportUser = '/v1/user/find/support';
  static const String mentionSearch = '/v1/user/mention-search';
  static const String userStatsCompletedCount = '/v1/user/stats/completed-count';
  static const String userStatsPreviewProfiles = '/v1/user/stats/preview-profiles';
  static String purposeInterestsCheck(String uid) => '/v1/user/$uid/purpose-interests/check';
  static String purposeInterests(String uid) => '/v1/user/$uid/purpose-interests';
  static String profileChangeEligibility(String uid) => '/v1/user/$uid/profile-change-eligibility';
  static String callStats(String uid) => '/v1/user/$uid/call-stats';
  static String usernameHistory(String uid) => '/v1/user/$uid/username-history';
  static String messagePrivacy(String uid) => '/v1/user/$uid/message-privacy';
  static String accountType(String uid) => '/v1/user/$uid/account-type';
  static String ghostMode(String uid) => '/v1/user/$uid/ghost-mode';
  static String canMessage(String uid) => '/v1/user/$uid/can-message';
  static const String appOpened = '/v1/user/app-opened';
  static const String deleteAccount = '/v1/user/account/delete';
  static const String batchProfiles = '/v1/user/batch-profiles';
  static String userProfileByUsername(String username) => '/v1/user/profile/$username';
  static const String myPasses = '/v1/user/me/passes';
  static const String redeemPass = '/v1/user/me/passes/redeem';
  static const String myPurchases = '/v1/user/me/purchases';

  // ── Upload ────────────────────────────────────────────────────────────
  static const String uploadSingle = '/api/v1/upload/single';
  static const String uploadDelete = '/api/v1/upload/delete';
  static const String uploadProfilePic = '/v1/upload/profile-pic';
  static String get filesUploadUrl => '${AppConfig.filesApiBaseUrl}/api/v1/upload/single';
  static String get filesDeleteUrl => '${AppConfig.filesApiBaseUrl}/api/v1/upload/delete';

  // ── Posts ─────────────────────────────────────────────────────────────
  static const String createPost = '/v1/posts';
  static String editPost(String id) => '/v1/posts/$id';
  static String deletePost(String id) => '/v1/posts/$id';
  static String userPosts(String profileUid, String requestingUid) => '/v1/posts/$profileUid/$requestingUid';
  static String postById(String id) => '/v1/posts/$id';
  static String postSingle(String id) => '/v1/posts/single/$id';
  static String postByShareSuffix(String suffix) => '/v1/posts/share/$suffix';
  static String postComments(String id) => '/v1/posts/$id/comments';

  // Posts v2
  static String recommendedPosts(String uid) => '/v2/posts/recommended/$uid';
  static String trendingPosts(String uid) => '/v2/posts/trending/$uid';
  static String followingPosts(String uid) => '/v2/posts/following/$uid';
  static String searchPosts(String uid) => '/v2/posts/search/$uid';
  static const String postFeedback = '/v2/posts/feedback';
  static String regenerateFeed(String uid) => '/v2/posts/regenerate/$uid';

  // ── Likes ─────────────────────────────────────────────────────────────
  static const String togglePostLike = '/v1/like/post/toggle';
  static const String toggleCommentLike = '/v1/like/comment/toggle';

  // ── Comments ──────────────────────────────────────────────────────────
  static String comments(String postId) => '/v1/comments/$postId';
  static const String createComment = '/v1/comments';
  static String deleteComment(String id) => '/v1/comments/$id';

  // ── Post Saves ────────────────────────────────────────────────────────
  static String savedPosts(String uid) => '/v1/post-saves/$uid';
  static const String togglePostSave = '/v1/post-saves/toggle';
  static String checkPostSave(String uid, String postId) => '/v1/post-saves/check/$uid/$postId';

  // ── Followers / Following ─────────────────────────────────────────────
  static const String toggleFollow = '/v1/followers/toggle';
  static const String toggleNotifyPosts = '/v1/followers/notify-posts/toggle';
  static const String removeFollower = '/v1/followers/remove';
  static String followers(String uid) => '/v1/followers/$uid/followers';
  static String following(String uid) => '/v1/followers/$uid/following';
  static String friends(String uid) => '/v1/followers/$uid/friends';
  static String followStatus(String currentUid, String targetUid) => '/v1/followers/$currentUid/status/$targetUid';
  static const String peopleSuggestions = '/v1/followers/suggestions';
  static const String dismissSuggestion = '/v1/followers/suggestions/dismiss';

  // ── Block ─────────────────────────────────────────────────────────────
  static const String blockUser = '/v1/block/block';
  static const String unblockUser = '/v1/block/unblock';
  static const String checkBlock = '/v1/block/check';
  static String blockList(String uid) => '/v1/block/list/$uid';

  // ── Chat ──────────────────────────────────────────────────────────────
  static const String createConversation = '/v1/chat/conversations';
  static String userConversations(String uid) => '/v1/chat/conversations/$uid';
  static String conversation(String id) => '/v1/chat/conversations/$id';
  static String acceptConversation(String id) => '/v1/chat/conversations/$id/accept';
  static String deleteConversation(String id) => '/v1/chat/conversations/$id';
  static String updateChatMessage(String id) => '/v1/chat/messages/$id';
  static const String chatLinkPreview = '/v1/chat/link-preview';
  static const String chatTranslate = '/v1/chat/translate';
  static const String chatContacts = '/v1/chat/contacts';
  static const String chatRequests = '/v1/chat/requests';

  // ── Groups ────────────────────────────────────────────────────────────
  static const String checkGroupInviteCode = '/v1/groups/invite-code/check';
  static const String createGroup = '/v1/groups/create';
  static const String publicGroupsList = '/v1/groups/public/list';
  static const String nearbyGroups = '/v1/groups/public/nearby';
  static const String joinGroup = '/v1/groups/join';
  static String shareableGroups(String uid) => '/v1/groups/shareable/$uid';
  static String userGroups(String uid) => '/v1/groups/user/$uid';
  static String groupByInviteCode(String code) => '/v1/groups/invite/$code';
  static String groupDetail(String id) => '/v1/groups/$id';
  static String groupMembers(String id) => '/v1/groups/$id/members';
  static String updateGroup(String id) => '/v1/groups/$id';
  static String addGroupMember(String id) => '/v1/groups/$id/members/add';
  static String removeGroupMember(String id) => '/v1/groups/$id/members/remove';
  static String promoteGroupMember(String id) => '/v1/groups/$id/members/promote';
  static String demoteGroupMember(String id) => '/v1/groups/$id/members/demote';
  static String leaveGroup(String id) => '/v1/groups/$id/leave';
  static String deleteGroup(String id) => '/v1/groups/$id';
  static String groupMessages(String id) => '/v1/groups/$id/messages';
  static String markGroupRead(String id) => '/v1/groups/$id/messages/read';
  static String deleteGroupMessage(String id) => '/v1/groups/messages/$id';
  static String editGroupMessage(String id) => '/v1/groups/messages/$id';
  static String groupEvents(String id) => '/v1/groups/$id/events';
  static String groupPermissions(String id) => '/v1/groups/$id/permissions';
  static String groupJoinRequests(String id) => '/v1/groups/$id/join-requests';
  static String approveJoinRequest(String reqId) => '/v1/groups/join-requests/$reqId/approve';
  static String rejectJoinRequest(String reqId) => '/v1/groups/join-requests/$reqId/reject';
  static String deleteJoinRequest(String reqId) => '/v1/groups/join-requests/$reqId';
  static String banGroupMember(String id) => '/v1/groups/$id/members/ban';
  static String unbanGroupMember(String id) => '/v1/groups/$id/members/unban';
  static String groupBannedUsers(String id) => '/v1/groups/$id/banned-users';
  static String groupRules(String id) => '/v1/groups/$id/rules';
  static String muteGroupMember(String id) => '/v1/groups/$id/members/mute';
  static String unmuteGroupMember(String id) => '/v1/groups/$id/members/unmute';
  static String groupPinnedMessages(String id) => '/v1/groups/$id/pinned-messages';
  static String pinGroupMessage(String groupId, String msgId) => '/v1/groups/$groupId/messages/$msgId/pin';
  static String groupMessageContext(String groupId, String msgId) => '/v1/groups/$groupId/messages/$msgId/context';
  static String groupActionLog(String id) => '/v1/groups/$id/action-log';
  static String groupDisappearingMessages(String id) => '/v1/groups/$id/disappearing-messages';

  // ── Group Topics ──────────────────────────────────────────────────────
  static String groupTopicsToggle(String groupId) => '/v1/groups/$groupId/topics/toggle';
  static String groupTopicsCount(String groupId) => '/v1/groups/$groupId/topics/count';
  static String groupTopics(String groupId) => '/v1/groups/$groupId/topics';
  static String groupTopic(String groupId, String topicId) => '/v1/groups/$groupId/topics/$topicId';
  static String groupTopicStatus(String groupId, String topicId) => '/v1/groups/$groupId/topics/$topicId/status';
  static String groupTopicPin(String groupId, String topicId) => '/v1/groups/$groupId/topics/$topicId/pin';
  static String groupTopicReplies(String groupId, String topicId) => '/v1/groups/$groupId/topics/$topicId/replies';
  static String groupTopicReply(String groupId, String topicId, String replyId) => '/v1/groups/$groupId/topics/$topicId/replies/$replyId';
  static String groupTopicVote(String groupId, String topicId) => '/v1/groups/$groupId/topics/$topicId/vote';
  static String groupTopicReplyVote(String groupId, String topicId, String replyId) => '/v1/groups/$groupId/topics/$topicId/replies/$replyId/vote';

  // ── Channels ──────────────────────────────────────────────────────────
  static const String featuredChannels = '/v1/channels/featured';
  static const String createChannel = '/v1/channels/create';
  static const String checkChannelUsername = '/v1/channels/check-username';
  static const String publicChannels = '/v1/channels/public';
  static const String myChannels = '/v1/channels/my';
  static String channelDetail(String id) => '/v1/channels/$id';
  static String channelInvite(String code) => '/v1/channels/invite/$code';
  static String channelMessages(String id) => '/v1/channels/$id/messages';
  static String channelMessage(String channelId, String msgId) => '/v1/channels/$channelId/messages/$msgId';
  static String subscribeChannel(String id) => '/v1/channels/$id/subscribe';
  static String muteChannel(String id) => '/v1/channels/$id/mute';
  static String channelPinned(String id) => '/v1/channels/$id/pinned';
  static String pinChannelMessage(String channelId, String msgId) => '/v1/channels/$channelId/messages/$msgId/pin';
  static String reactChannelMessage(String channelId, String msgId) => '/v1/channels/$channelId/messages/$msgId/react';
  static String channelAdmins(String id) => '/v1/channels/$id/admins';
  static String channelAdmin(String channelId, String userId) => '/v1/channels/$channelId/admins/$userId';
  static String channelSubscribers(String id) => '/v1/channels/$id/subscribers';
  static String channelSubscriber(String channelId, String userId) => '/v1/channels/$channelId/subscribers/$userId';
  static String channelMarkRead(String id) => '/v1/channels/$id/mark-read';
  static String channelMessageViews(String id) => '/v1/channels/$id/messages/views';
  static String channelPollVote(String channelId, String msgId) => '/v1/channels/$channelId/messages/$msgId/poll/vote';
  static String channelMedia(String id) => '/v1/channels/$id/media';
  static String channelLinks(String id) => '/v1/channels/$id/links';
  static const String resolveUsername = '/v1/username/resolve';

  // ── Audio Rooms ───────────────────────────────────────────────────────
  static const String audioRooms = '/v1/audio-rooms';
  static const String audioRoomSettings = '/v1/audio-rooms/settings';
  static const String myAudioRoomHistory = '/v1/audio-rooms/my-history';
  static const String myAudioRoom = '/v1/audio-rooms/my-room';
  static const String upcomingAudioRooms = '/v1/audio-rooms/upcoming';
  static const String myScheduledAudioRooms = '/v1/audio-rooms/my-schedules';
  static String audioRoom(String id) => '/v1/audio-rooms/$id';
  static String joinAudioRoom(String id) => '/v1/audio-rooms/$id/join';
  static String leaveAudioRoom(String id) => '/v1/audio-rooms/$id/leave';
  static String endAudioRoom(String id) => '/v1/audio-rooms/$id/end';
  static String startAudioRoom(String id) => '/v1/audio-rooms/$id/start';
  static String audioRoomParticipants(String id) => '/v1/audio-rooms/$id/participants';
  static String audioRoomStage(String id) => '/v1/audio-rooms/$id/stage';
  static String audioRoomParticipantRole(String id, String uid) => '/v1/audio-rooms/$id/participants/$uid/role';
  static String audioRoomParticipantSeat(String id, String uid) => '/v1/audio-rooms/$id/participants/$uid/seat';
  static String kickFromAudioRoom(String id, String uid) => '/v1/audio-rooms/$id/kick/$uid';
  static String banFromAudioRoom(String id, String uid) => '/v1/audio-rooms/$id/ban/$uid';
  static String audioRoomBans(String id) => '/v1/audio-rooms/$id/bans';
  static String unbanFromAudioRoom(String id, String uid) => '/v1/audio-rooms/$id/bans/$uid';
  static String audioRoomGroupActive(String groupId) => '/v1/audio-rooms/group/$groupId/all-active';
  static String audioRoomGroupScheduled(String groupId) => '/v1/audio-rooms/group/$groupId/scheduled';
  static String audioRoomRating(String id) => '/v1/audio-rooms/$id/rating';
  static String audioRoomReviews(String id) => '/v1/audio-rooms/$id/reviews';

  // ── Voice / Video Rooms ───────────────────────────────────────────────
  static const String joinVoiceRoom = '/v1/voice-room/join';
  static String voiceRoomStatus(String id) => '/v1/voice-room/status/$id';
  static String voiceRoomDuration(String id) => '/v1/voice-room/duration/$id';
  static String voiceRoomEnd(String id) => '/v1/voice-room/end/$id';
  static const String joinVideoRoom = '/v1/video-room/join';
  static String videoRoomStatus(String id) => '/v1/video-room/status/$id';
  static String videoRoomDuration(String id) => '/v1/video-room/duration/$id';
  static String videoRoomEnd(String id) => '/v1/video-room/end/$id';

  // ── Random Chat ───────────────────────────────────────────────────────
  static const String joinRandomChat = '/v1/random-chat/join';
  static String endRandomChatRoom(String id) => '/v1/random-chat/room/$id/end';

  // ── Notifications ─────────────────────────────────────────────────────
  static String notifications(String uid) => '/v1/notifications/$uid';
  static String notificationCounts(String uid) => '/v1/notifications/$uid/counts';
  static String markNotificationRead(String id) => '/v1/notifications/$id/read';
  static const String markAllNotificationsRead = '/v1/notifications/read-all';
  static const String markAllNotificationsSeen = '/v1/notifications/seen-all';
  static String deleteNotification(String id) => '/v1/notifications/$id';
  static const String notificationPreferences = '/v1/notification-settings/preferences';
  static String notificationPreference(String key) => '/v1/notification-settings/preferences/$key';

  // ── FCM ───────────────────────────────────────────────────────────────
  static const String registerPushToken = '/v1/fcm/token/register';
  static const String deletePushToken = '/v1/fcm/token/delete';

  // ── Profile Interaction ───────────────────────────────────────────────
  static const String likeProfile = '/v1/profile-interaction/like';
  static const String dislikeProfile = '/v1/profile-interaction/dislike';
  static String profileInteraction(String targetUid) => '/v1/profile-interaction/interaction/$targetUid';
  static const String whoLikedMe = '/v1/profile-interaction/who-liked-me';
  static const String mutualMatches = '/v1/profile-interaction/mutual-matches';
  static const String undoProfileInteraction = '/v1/profile-interaction/undo';
  static const String unmatch = '/v1/profile-interaction/unmatch';
  static const String profileInteractionStats = '/v1/profile-interaction/stats';
  static const String unreciprocatedLikes = '/v1/profile-interaction/unreciprocated-likes';

  // ── Profile Visits ────────────────────────────────────────────────────
  static String profileVisits(String uid) => '/v1/profile-visits/$uid';
  static String markProfileVisitsRead(String uid) => '/v1/profile-visits/$uid/mark-read';
  static String profileVisitsUnreadCount(String uid) => '/v1/profile-visits/$uid/unread-count';

  // ── Streaks ───────────────────────────────────────────────────────────
  static String streaks(String uid) => '/v1/streaks/$uid';
  static String streakCalendar(String uid) => '/v1/streaks/$uid/calendar';
  static const String streakLeaderboard = '/v1/streaks/leaderboard';
  static const String streakFriendsLeaderboard = '/v1/streaks/friends-leaderboard';
  static String freezeStreak(String uid) => '/v1/streaks/$uid/freeze';

  // ── Levels / Rank / Merit ─────────────────────────────────────────────
  static String userLevel(String uid) => '/v1/levels/user/$uid';
  static String userRank(String uid) => '/v1/rank/user/$uid';
  static const String myMerit = '/v1/merit/me';

  // ── Missions ──────────────────────────────────────────────────────────
  static String userMissions(String uid) => '/v1/missions/user/$uid';
  static String userMissionStats(String uid) => '/v1/missions/user/$uid/stats';
  static const String collectMission = '/v1/missions/collect';
  static const String updateMissionProgress = '/v1/missions/update-progress';

  // ── Referral ──────────────────────────────────────────────────────────
  static const String myReferralCode = '/v1/referral/my-code';
  static const String validateReferral = '/v1/referral/validate';
  static const String submitReferral = '/v1/referral/submit';
  static const String referralStats = '/v1/referral/stats';
  static const String myReferrals = '/v1/referral/my-referrals';
  static const String referralMilestones = '/v1/referral/milestones';
  static const String referralLeaderboard = '/v1/referral/leaderboard';
  static const String referralWithdraw = '/v1/referral/withdraw';
  static const String referralTransferToWallet = '/v1/referral/transfer-to-wallet';
  static const String myReferrer = '/v1/referral/my-referrer';

  // ── Location ──────────────────────────────────────────────────────────
  static const String updateLocation = '/v1/location/update';
  static const String nearbyPeople = '/v1/location/nearby';
  static const String nearbyBirthdays = '/v1/location/birthdays';
  static const String locationBounds = '/v1/location/bounds';
  static const String locationByCity = '/v1/location/city';
  static const String locationAutocomplete = '/v1/location/autocomplete';
  static const String schoolAutocomplete = '/v1/location/school-autocomplete';

  // ── Hashtags ──────────────────────────────────────────────────────────
  static const String popularHashtags = '/v1/hashtags/popular';
  static const String searchHashtags = '/v1/hashtags/search';

  // ── Explore / Discover ────────────────────────────────────────────────
  static const String exploreBanners = '/v1/config/explore-banners';

  // ── Search ────────────────────────────────────────────────────────────
  static const String search = '/v1/search';

  // ── User Matching ─────────────────────────────────────────────────────
  static const String triggerMatching = '/v1/user-matching/trigger-calculation';
  static String userMatch(String uid) => '/v1/user-matching/match/$uid';
  static const String userMatches = '/v1/user-matching/matches';

  // ── Excluded Users ────────────────────────────────────────────────────
  static const String addExcludedUser = '/v2/excluded-users/add';
  static const String removeExcludedUser = '/v2/excluded-users/remove';
  static String excludedUsers(String uid) => '/v2/excluded-users/$uid';

  // ── Engagement / Shares / Report / Feedback ───────────────────────────
  static const String trackView = '/v1/engagement/track-view';
  static const String externalShare = '/v1/shares/external';
  static const String report = '/v1/report';
  static const String reportCategories = '/v1/report/categories';
  static const String submitBug = '/v1/feedback/bugs';
  static const String submitSuggestion = '/v1/feedback/suggestions';

  // ── Config / Maintenance / Verification ───────────────────────────────
  static const String maintenanceStatus = '/v1/maintenance/status';
  static String uploadLimitConfig(String uid) => '/v1/config/upload-limit/$uid';
  static String postLimitConfig(String uid) => '/v1/config/post-limit/$uid';
  static const String createActionsConfig = '/v1/config/create-actions';
  static const String verificationEligibility = '/v1/verification/eligibility';
  static const String verificationStatus = '/v1/verification/status';
  static const String submitVerification = '/v1/verification/submit';

  // ── Wallet ────────────────────────────────────────────────────────────
  static const String wallet = '/v1/wallet';
  static const String walletPayout = '/v1/wallet/payout';
  static const String walletSettings = '/v1/wallet/settings';

  // ── Stickers ──────────────────────────────────────────────────────────
  static const String stickerPacks = '/v1/stickers/packs';

  // ── WiStay ────────────────────────────────────────────────────────────
  static const String wistayProperties = '/v1/wistay/properties';
  static String wistayProperty(String id) => '/v1/wistay/properties/$id';
  static const String wistayMyProperties = '/v1/wistay/my-properties';
  static const String wistayFavorites = '/v1/wistay/favorites';
  static String wistayFavorite(String id) => '/v1/wistay/favorites/$id';
  static const String wistayInquiries = '/v1/wistay/inquiries';
  static String wistayPropertyInquiries(String id) => '/v1/wistay/properties/$id/inquiries';
  static String wistayInquiry(String id) => '/v1/wistay/inquiries/$id';
  static const String wistayNearby = '/v1/wistay/nearby';
  static const String wistayReviews = '/v1/wistay/reviews';
  static String wistayPropertyReviews(String id) => '/v1/wistay/properties/$id/reviews';

  // ── Auth IP Check ─────────────────────────────────────────────────────
  static const String ipLookup = '/v1/auth/ip-lookup';
  static const String blockedIsps = '/v1/auth/blocked-isps';

  // ── GraphQL ───────────────────────────────────────────────────────────
  static const String graphql = '/graphql';
}
