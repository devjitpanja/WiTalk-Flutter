import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme_colors.dart';
import '../../services/audio_room_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/connect/personal_adda_card.dart';

class CommunityAddaListScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupPicture;
  final bool isMember;
  final String? groupInviteCode;
  final bool groupIsMonetized;

  const CommunityAddaListScreen({
    super.key,
    required this.groupId,
    this.groupName = 'Community',
    this.groupPicture,
    this.isMember = true,
    this.groupInviteCode,
    this.groupIsMonetized = false,
  });

  @override
  ConsumerState<CommunityAddaListScreen> createState() => _CommunityAddaListScreenState();
}

class _CommunityAddaListScreenState extends ConsumerState<CommunityAddaListScreen> {
  List<Map<String, dynamic>> _addas = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _canTerminate = false;

  @override
  void initState() {
    super.initState();
    _fetchAddas();
  }

  Future<void> _fetchAddas([bool isRefresh = false]) async {
    if (isRefresh) setState(() => _refreshing = true);
    try {
      final res = await audioRoomService.getGroupActiveRooms(widget.groupId);
      if (mounted) {
        setState(() {
          _addas = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _canTerminate = res['can_terminate'] == true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _addas = []);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _handleJoin(Map<String, dynamic> adda) {
    if (!widget.isMember) {
      final inviteCode = widget.groupInviteCode ?? adda['group_invite_code']?.toString();
      final isMonetized = widget.groupIsMonetized || (adda['group_is_monetized'] == true || adda['group_is_monetized'] == 1);
      if (isMonetized && inviteCode != null && inviteCode.isNotEmpty) {
        context.push('/community-info/$inviteCode');
        return;
      }
    }
    
    final roomId = adda['room_id']?.toString() ?? adda['id']?.toString() ?? '';
    if (roomId.isNotEmpty) {
      context.pushReplacement('/live-audio/$roomId', extra: {
        'room_name': adda['room_name']?.toString() ?? 'Community Adda',
        'is_host': adda['host_uid']?.toString() == ref.read(authProvider).uid,
        'host_uid': adda['host_uid']?.toString(),
      });
    }
  }

  void _showTerminateSheet(Map<String, dynamic> adda) {
    // Terminate UI goes here if needed.
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            if (widget.groupPicture != null && widget.groupPicture!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: widget.groupPicture!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.group, size: 18, color: Colors.white),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle), margin: const EdgeInsets.only(right: 5)),
                      Text(
                        _loading ? 'Loading...' : '${_addas.length} LIVE',
                        style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () => _fetchAddas(true),
                ),
                if (_addas.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Icon(Icons.mic_off, size: 48, color: c.textSecondary),
                        const SizedBox(height: 12),
                        Text('No active addas', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('No community addas are live right now.', style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit'), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(14).copyWith(bottom: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final adda = _addas[index];
                          return PersonalAddaCard(
                            room: adda,
                            paletteIndex: index,
                            onJoinRoom: _handleJoin,
                          );
                        },
                        childCount: _addas.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
