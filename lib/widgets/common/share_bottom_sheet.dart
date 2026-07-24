import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'package:url_launcher/url_launcher.dart';
import '../../api/app_endpoints.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_api_service.dart';
import '../../theme/theme_colors.dart';

// ── Data models ────────────────────────────────────────────────────────────────

enum ShareType { post, adda }

class SharePostData {
  final String? id;
  final String? suffix;
  final String? content;
  final String? caption;
  final String? userId;
  final Map<String, dynamic>? user;
  final dynamic media; // JSON string or List
  final String? mediaType;
  final dynamic images;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final dynamic mediaData;
  final bool isMini;

  const SharePostData({
    this.id,
    this.suffix,
    this.content,
    this.caption,
    this.userId,
    this.user,
    this.media,
    this.mediaType,
    this.images,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaData,
    this.isMini = false,
  });

  factory SharePostData.fromMap(Map<String, dynamic> p) => SharePostData(
        id: p['id']?.toString(),
        suffix: p['suffix']?.toString(),
        content: (p['content'] ?? p['caption'])?.toString(),
        caption: p['caption']?.toString(),
        userId: (p['user_id'] ?? p['user']?['id'])?.toString(),
        user: p['user'] as Map<String, dynamic>?,
        media: p['media'],
        mediaType: p['media_type']?.toString(),
        images: p['images'],
        mediaUrl: p['media_url']?.toString(),
        thumbnailUrl: p['thumbnail_url']?.toString(),
        mediaData: p['media_data'],
        isMini: p['is_mini'] == true || p['type'] == 'mini',
      );
}

class ShareAddaData {
  final String? roomId;
  final String? roomName;
  final String? hostUid;
  final String? inviteToken;
  final bool isPublic;

  const ShareAddaData({
    this.roomId,
    this.roomName,
    this.hostUid,
    this.inviteToken,
    this.isPublic = true,
  });
}

// ── Public entry point ─────────────────────────────────────────────────────────

void showShareBottomSheet(
  BuildContext context, {
  SharePostData? postData,
  ShareAddaData? addaData,
  ShareType shareType = ShareType.post,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => _ShareSheet(
      postData: postData,
      addaData: addaData,
      shareType: shareType,
    ),
  );
}

// ── Main sheet ────────────────────────────────────────────────────────────────

class _ShareSheet extends ConsumerStatefulWidget {
  final SharePostData? postData;
  final ShareAddaData? addaData;
  final ShareType shareType;

  const _ShareSheet({this.postData, this.addaData, required this.shareType});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _groups = [];
  bool _loadingFriends = false;
  bool _loadingGroups = false;

  final _selectedUsers = <String>{};
  final _selectedGroups = <String>{};
  bool _sending = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _query = _searchCtrl.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final uid = ref.read(authProvider).uid;
    if (uid == null) return;
    await Future.wait([_loadFriends(uid), _loadGroups(uid)]);
  }

  Future<void> _loadFriends(String uid) async {
    if (!mounted) return;
    setState(() => _loadingFriends = true);
    try {
      final res = await dioClient.get(AppEndpoints.friends(uid),
          queryParameters: {'page': 1, 'limit': 100});
      final d = res.data['data'];
      final list = (d is Map ? d['friends'] : d) as List? ?? [];
      if (mounted) setState(() => _friends = List<Map<String, dynamic>>.from(list));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _loadGroups(String uid) async {
    if (!mounted) return;
    setState(() => _loadingGroups = true);
    try {
      final res = await dioClient.get(AppEndpoints.shareableGroups(uid));
      final d = res.data['data'];
      final list = d is List ? d : <dynamic>[];
      if (mounted) setState(() => _groups = List<Map<String, dynamic>>.from(list));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  // ── Data shaping ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _allChatUsers {
    final conversations = ref.read(chatProvider).conversations;
    final chatUserIds = <String>{};
    final chatUsers = conversations
        .where((c) => c.otherUser != null)
        .map((c) {
          chatUserIds.add(c.otherUser!['id'].toString());
          return {
            'type': 'user',
            'id': c.otherUser!['id'].toString(),
            'name': c.otherUser!['name'],
            'username': c.otherUser!['username'],
            'profile_pic': c.otherUser!['profile_pic'],
            'conversation_id': c.id,
          };
        })
        .toList();

    final friendUsers = _friends
        .where((f) => !chatUserIds.contains(f['id']?.toString()))
        .map((f) => {
              'type': 'user',
              'id': f['id'].toString(),
              'name': f['name'],
              'username': f['username'],
              'profile_pic': f['profile_pic'],
              'conversation_id': null,
            })
        .toList();

    return [...chatUsers, ...friendUsers];
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final all = _allChatUsers;
    if (_query.trim().isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((u) =>
            (u['name']?.toString().toLowerCase().contains(q) ?? false) ||
            (u['username']?.toString().toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredGroups {
    if (_query.trim().isEmpty) return _groups;
    final q = _query.toLowerCase();
    return _groups
        .where((g) => g['name']?.toString().toLowerCase().contains(q) ?? false)
        .toList();
  }

  // ── Share URL / message ───────────────────────────────────────────────────────

  String _shareUrl() {
    if (widget.shareType == ShareType.adda) {
      final a = widget.addaData!;
      final token = (!a.isPublic && a.inviteToken != null) ? a.inviteToken! : (a.roomId ?? '');
      return 'https://witalk.in/adda/$token';
    }
    final p = widget.postData!;
    return p.suffix != null
        ? 'https://witalk.in/p/${p.suffix}'
        : 'https://witalk.in/post/${p.id}';
  }

  String _shareMessage() {
    final url = _shareUrl();
    if (widget.shareType == ShareType.adda) {
      return 'Join my adda "${widget.addaData?.roomName ?? 'WiTalk Adda'}" on WiTalk!\n$url';
    }
    final content = widget.postData?.content ?? widget.postData?.caption ?? '';
    return content.isNotEmpty
        ? '${content.substring(0, content.length > 100 ? 100 : content.length)}${content.length > 100 ? '...' : ''}\n\nCheck out this post: $url'
        : 'Check out this post: $url';
  }

  // ── Quick actions ─────────────────────────────────────────────────────────────

  Future<void> _shareWhatsApp() async {
    final msg = _shareMessage();
    final waUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri);
      _trackExternalShare('whatsapp');
    } else {
      _showSnack('WhatsApp is not installed');
    }
  }

  Future<void> _shareWhatsAppStatus() async {
    final url = _shareUrl();
    final waUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(url)}');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri);
      _trackExternalShare('whatsapp_status');
    } else {
      _showSnack('WhatsApp is not installed');
    }
  }

  Future<void> _shareSystem() async {
    final msg = _shareMessage();
    await SharePlus.instance.share(ShareParams(text: msg));
    _trackExternalShare('system');
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl()));
    _trackExternalShare('copy_link');
    _showSnack('Link copied');
  }

  void _trackExternalShare(String destination) {
    final postId = widget.postData?.id;
    final uid = ref.read(authProvider).uid;
    if (postId == null || uid == null) return;
    dioClient.post(AppEndpoints.externalShare, data: {
      'postId': postId,
      'userId': uid,
      'shareDestination': destination,
    }).ignore();
  }

  // ── Send in-app ───────────────────────────────────────────────────────────────

  Future<void> _handleSend() async {
    if (_totalSelected == 0) return;
    setState(() => _sending = true);
    try {
      final uid = ref.read(authProvider).uid;
      if (uid == null) return;

      if (widget.shareType == ShareType.adda) {
        final url = _shareUrl();
        final msg = 'Join my adda\n$url';

        for (final userId in _selectedUsers) {
          final user = _allChatUsers.firstWhere((u) => u['id'] == userId, orElse: () => {});
          if (user.isEmpty) continue;
          final convId = user['conversation_id'] as String?;
          if (convId != null) {
            ref.read(chatProvider.notifier).sendMessage(
                  conversationId: convId,
                  receiverId: userId,
                  content: msg,
                );
          } else {
            final res = await chatApiService.createConversation(
                userId: uid, otherUserId: userId);
            final newConvId = res['data']?['id']?.toString();
            if (newConvId != null) {
              ref.read(chatProvider.notifier).sendMessage(
                    conversationId: newConvId,
                    receiverId: userId,
                    content: msg,
                  );
            }
          }
        }

        for (final groupId in _selectedGroups) {
          try {
            await chatApiService.sendGroupMessageRest(
                groupId, senderId: uid, content: msg, messageType: 'text');
          } catch (_) {}
        }
      } else {
        // post / reel share
        final p = widget.postData!;
        final shareUrl = _shareUrl();
        final shareMsg = _shareMessage();
        final isReel = p.mediaType == 'video' || p.isMini;
        final messageType = isReel ? 'shared_reel' : 'shared_post';

        String? mediaUrl = p.mediaUrl ?? p.thumbnailUrl;
        String? videoUrl;
        String? thumbnailUrl;

        void parseMedia(dynamic raw) {
          try {
            final arr = raw is List ? raw : jsonDecode(raw as String) as List;
            if (arr.isNotEmpty) {
              final first = arr[0] as Map;
              if (first['type'] == 'video') {
                videoUrl ??= first['url']?.toString();
                thumbnailUrl ??= first['thumbnail']?.toString();
                mediaUrl ??= thumbnailUrl ?? videoUrl;
              } else {
                mediaUrl ??= first['url']?.toString();
              }
            }
          } catch (_) {}
        }

        if (p.media != null) parseMedia(p.media);
        if (mediaUrl == null && p.mediaData != null) parseMedia(p.mediaData);
        if (mediaUrl == null && p.images != null) {
          try {
            final arr = p.images is List
                ? p.images as List
                : jsonDecode(p.images.toString()) as List;
            if (arr.isNotEmpty) mediaUrl = arr[0].toString();
          } catch (_) {}
        }

        // postType: 'video' for reels, 'mini' for mini-screen posts, 'post' otherwise.
        // RN SharedPostCard checks postType === 'video' || 'mini' to render the reel layout.
        final postType = isReel
            ? (p.mediaType == 'video' ? 'video' : 'mini')
            : (p.mediaType ?? 'post');

        // Build the flat metadata object exactly as RN does — must be a JSON string when
        // sent over the socket because RN's chatStore stores and echoes metadata as a string,
        // and the RN receiver does JSON.parse(message.metadata) to read it back.
        final metadataMap = {
          'type': 'shared_post',
          'postId': p.id,
          'suffix': p.suffix,
          'postType': postType,
          'userId': p.userId,
          'shareUrl': shareUrl,
          'media_url': mediaUrl,
          'video_url': videoUrl,
          'thumbnail_url': thumbnailUrl,
          'name': p.user?['name'],
          'username': p.user?['username'],
          'profile_pic': p.user?['profile_pic'],
          'content': p.content ?? p.caption,
          'caption': p.content ?? p.caption,
        };
        for (final userId in _selectedUsers) {
          final user = _allChatUsers.firstWhere((u) => u['id'] == userId, orElse: () => {});
          if (user.isEmpty) continue;
          final convId = user['conversation_id'] as String?;
          if (convId != null) {
            ref.read(chatProvider.notifier).sendMessage(
                  conversationId: convId,
                  receiverId: userId,
                  content: shareMsg,
                  messageType: messageType,
                  mediaData: metadataMap,
                  metadata: metadataMap,
                );
          } else {
            final res = await chatApiService.createConversation(
                userId: uid, otherUserId: userId);
            final newConvId = res['data']?['id']?.toString();
            if (newConvId != null) {
              ref.read(chatProvider.notifier).sendMessage(
                    conversationId: newConvId,
                    receiverId: userId,
                    content: shareMsg,
                    messageType: messageType,
                    mediaData: metadataMap,
                    metadata: metadataMap,
                  );
            }
          }
        }

        // Group REST: metadata must be a JSON string to match RN's REST payload format.
        // RN sends `metadata: sharedPostMetadata` where sharedPostMetadata is JSON.stringify'd.
        final metadataString = jsonEncode(metadataMap);
        for (final groupId in _selectedGroups) {
          try {
            await dioClient.post(
              AppEndpoints.groupMessages(groupId),
              data: {
                'group_id': groupId,
                'sender_id': uid,
                'content': shareMsg,
                'message_type': messageType,
                'metadata': metadataString,
              },
            );
          } catch (_) {}
        }


        // record in-app share
        final allRecipients = [
          ..._selectedUsers,
          ..._selectedGroups.map((id) => 'group_$id'),
        ];
        dioClient.post('/v1/shares/in-app', data: {
          'postId': p.id,
          'userId': uid,
          'recipientIds': allRecipients,
          'shareDestination': _selectedGroups.isNotEmpty ? 'in_app_group' : 'in_app_chat',
        }).ignore();
      }

      _selectedUsers.clear();
      _selectedGroups.clear();
      _showSnack('Sent successfully');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int get _totalSelected => _selectedUsers.length + _selectedGroups.length;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.of(context).padding.bottom;
    final loading = _loadingFriends || _loadingGroups;

    final users = _filteredUsers;
    final groups = _filteredGroups;
    final hasContent = users.isNotEmpty || groups.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // constrain to 85% of screen height
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Share',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 17,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c.border.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Divider(color: c.border.withValues(alpha: 0.4), height: 1),

          // ── Search ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                Icon(Icons.search, size: 18, color: c.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      hintText: 'Search people or groups...',
                      hintStyle: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit'),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchCtrl.clear(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(Icons.cancel, size: 17, color: c.textSecondary),
                    ),
                  ),
              ]),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────────
          Flexible(
            child: loading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: c.primary, strokeWidth: 2.5)),
                  )
                : !hasContent
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline, size: 52, color: c.border),
                          const SizedBox(height: 12),
                          Text(
                            _query.isNotEmpty ? 'No results found' : 'No contacts available',
                            style: TextStyle(color: c.textSecondary, fontSize: 15, fontFamily: 'Outfit'),
                          ),
                        ]),
                      )
                    : ListView(
                        controller: _scrollCtrl,
                        shrinkWrap: true,
                        padding: EdgeInsets.only(bottom: _totalSelected > 0 ? 80 : 4),
                        children: [
                          if (users.isNotEmpty) ...[
                            _SectionHeader(
                                title: 'Direct Messages',
                                count: users.length,
                                c: c),
                            _UsersRow(
                              users: users,
                              selectedIds: _selectedUsers,
                              onTap: (id) => setState(() {
                                _selectedUsers.contains(id)
                                    ? _selectedUsers.remove(id)
                                    : _selectedUsers.add(id);
                              }),
                            ),
                          ],
                          if (groups.isNotEmpty) ...[
                            _SectionHeader(
                                title: 'Groups & Channels',
                                count: groups.length,
                                c: c),
                            ...groups.map((g) => _GroupRow(
                                  group: g,
                                  isSelected: _selectedGroups.contains(g['id']?.toString()),
                                  onTap: () {
                                    final id = g['id']?.toString() ?? '';
                                    setState(() {
                                      _selectedGroups.contains(id)
                                          ? _selectedGroups.remove(id)
                                          : _selectedGroups.add(id);
                                    });
                                  },
                                  c: c,
                                )),
                          ],
                        ],
                      ),
          ),

          // ── Footer ──────────────────────────────────────────────────────────
          _Footer(
            totalSelected: _totalSelected,
            sending: _sending,
            onSend: _handleSend,
            onWhatsApp: _shareWhatsApp,
            onWhatsAppStatus: _shareWhatsAppStatus,
            onMore: _shareSystem,
            onCopyLink: _copyLink,
            bottomPadding: bottom,
            c: c,
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final ThemeColors c;
  const _SectionHeader({required this.title, required this.count, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8),
        ),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: TextStyle(
                    color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

// ── Horizontal users row ──────────────────────────────────────────────────────

class _UsersRow extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final Set<String> selectedIds;
  final ValueChanged<String> onTap;
  const _UsersRow({required this.users, required this.selectedIds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 94,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: users.length,
        itemBuilder: (_, i) {
          final u = users[i];
          final id = u['id']?.toString() ?? '';
          final isSelected = selectedIds.contains(id);
          final pic = u['profile_pic']?.toString();
          return GestureDetector(
            onTap: () => onTap(id),
            child: SizedBox(
              width: 72,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _Avatar(url: pic, size: 58, radius: 29, c: c),
                    if (isSelected)
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, size: 22, color: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  u['name']?.toString() ?? '',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontSize: 11, fontFamily: 'Outfit', height: 1.3),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Group row ─────────────────────────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeColors c;
  const _GroupRow({required this.group, required this.isSelected, required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) {
    final isAdmin = group['user_role'] == 'admin' || group['user_role'] == 'super_admin';
    final memberCount = group['member_count'] ?? 0;
    final isPublic = group['group_type'] == 'public';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: isSelected ? c.primary.withValues(alpha: 0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _Avatar(
            url: group['picture']?.toString(),
            size: 48,
            radius: 12,
            isGroup: true,
            c: c,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    group['name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.text, fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('admin',
                        style: TextStyle(color: c.primary, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                '${isPublic ? 'Public' : 'Private'} · $memberCount members',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit'),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? c.primary : Colors.transparent,
              border: Border.all(color: isSelected ? c.primary : c.border, width: 2),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final bool isGroup;
  final ThemeColors c;
  const _Avatar({this.url, required this.size, required this.radius, this.isGroup = false, required this.c});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(radius)),
        child: Icon(isGroup ? Icons.group : Icons.person, size: size * 0.4, color: c.textSecondary),
      );
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final int totalSelected;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onWhatsApp;
  final VoidCallback onWhatsAppStatus;
  final VoidCallback onMore;
  final VoidCallback onCopyLink;
  final double bottomPadding;
  final ThemeColors c;

  const _Footer({
    required this.totalSelected,
    required this.sending,
    required this.onSend,
    required this.onWhatsApp,
    required this.onWhatsAppStatus,
    required this.onMore,
    required this.onCopyLink,
    required this.bottomPadding,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.bottomSheetBg,
        border: Border(top: BorderSide(color: c.border.withValues(alpha: 0.4))),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPadding > 0 ? bottomPadding : 16),
      child: totalSelected == 0
          ? Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _QuickBtn(icon: Icons.chat_rounded, color: const Color(0xFF25D366), label: 'WhatsApp', onTap: onWhatsApp, c: c),
              _QuickBtn(icon: Icons.history, color: const Color(0xFF25D366), label: 'WA\nStatus', onTap: onWhatsAppStatus, c: c),
              _QuickBtn(icon: Icons.share_rounded, color: c.primary, label: 'More', onTap: onMore, c: c),
              _QuickBtn(icon: Icons.content_copy_rounded, color: c.textSecondary, label: 'Copy link', onTap: onCopyLink, c: c, outline: true),
            ])
          : SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: sending ? null : onSend,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: sending
                      ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Send to $totalSelected ${totalSelected == 1 ? 'recipient' : 'recipients'}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                          ),
                        ]),
                ),
              ),
            ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final ThemeColors c;
  final bool outline;
  const _QuickBtn({required this.icon, required this.color, required this.label, required this.onTap, required this.c, this.outline = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: outline ? c.surface : color,
              borderRadius: BorderRadius.circular(16),
              border: outline ? Border.all(color: c.border, width: 1.5) : null,
            ),
            child: Icon(icon, size: 22, color: outline ? c.textSecondary : Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit', height: 1.3),
          ),
        ]),
      ),
    );
  }
}
