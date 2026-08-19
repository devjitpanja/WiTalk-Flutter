import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../cache/witalk_image_cache.dart';

import '../../theme/theme_colors.dart';
import '../../services/audio_room_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/connect/personal_adda_card.dart';
import '../../utils/mic_permission_utils.dart';

const _kTerminateReasons = [
  (key: 'abusive_language', label: 'Abusive language', icon: Icons.warning),
  (key: 'political_discussion', label: 'Political discussion', icon: Icons.gavel),
  (key: 'hate_speech', label: 'Hate speech / discrimination', icon: Icons.do_not_disturb),
  (key: 'spam_promotion', label: 'Spam or promotion', icon: Icons.campaign),
  (key: 'misinformation', label: 'Spreading misinformation', icon: Icons.info),
  (key: 'adult_content', label: 'Adult / inappropriate content', icon: Icons.block),
  (key: 'other', label: 'Other (describe below)', icon: Icons.edit),
];

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
  bool _canTerminate = false;

  @override
  void initState() {
    super.initState();
    _fetchAddas();
  }

  Future<void> _fetchAddas([bool isRefresh = false]) async {
    try {
      final res = await audioRoomService.getGroupActiveRooms(widget.groupId);
      if (mounted) {
        setState(() {
          _addas = res['success'] == true && res['data'] is List
              ? (res['data'] as List).cast<Map<String, dynamic>>()
              : [];
          _canTerminate = res['can_terminate'] == true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _addas = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleJoin(Map<String, dynamic> adda) async {
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
      if (!await checkMicPermission(context)) return;
      if (!mounted) return;
      context.pushReplacement('/live-audio/$roomId', extra: {
        'room_name': adda['room_name']?.toString() ?? 'Community Adda',
        'is_host': adda['host_uid']?.toString() == ref.read(authProvider).uid,
        'host_uid': adda['host_uid']?.toString(),
      });
    }
  }

  void _showTerminateSheet(Map<String, dynamic> adda) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TerminateSheet(
        adda: adda,
        onConfirm: (reason, customReason) async {
          await audioRoomService.terminateAdda(
            adda['room_id']?.toString() ?? '',
            reason,
            customReason: customReason,
          );
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 600));
            _fetchAddas(true);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

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
                  cacheManager: WiTalkImageCache(),
                  imageUrl: widget.groupPicture!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 36,
                height: 36,
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
                    style: TextStyle(
                      color: c.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                        margin: const EdgeInsets.only(right: 5),
                      ),
                      Text(
                        _loading ? 'Loading…' : '${_addas.length} LIVE',
                        style: const TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
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
                        Icon(Icons.mic_off, size: 48, color: c.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No active addas',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No community addas are live right now.',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 14,
                            fontFamily: 'Outfit',
                          ),
                          textAlign: TextAlign.center,
                        ),
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
                            onTerminate: _canTerminate ? _showTerminateSheet : null,
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

class _TerminateSheet extends StatefulWidget {
  final Map<String, dynamic> adda;
  final Future<void> Function(String reason, String? customReason) onConfirm;

  const _TerminateSheet({required this.adda, required this.onConfirm});

  @override
  State<_TerminateSheet> createState() => _TerminateSheetState();
}

class _TerminateSheetState extends State<_TerminateSheet> {
  String? _selectedReason;
  final _customReasonController = TextEditingController();
  bool _terminating = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _selectedReason != null &&
      (_selectedReason != 'other' || _customReasonController.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canConfirm) return;
    setState(() => _terminating = true);
    try {
      await widget.onConfirm(
        _selectedReason!,
        _selectedReason == 'other' ? _customReasonController.text.trim() : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // keep sheet open on error
    } finally {
      if (mounted) setState(() => _terminating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: c.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x18EF4444),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.stop_circle, size: 22, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terminate Adda',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    if (widget.adda['room_name'] != null)
                      Text(
                        widget.adda['room_name'].toString(),
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontFamily: 'Outfit',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'SELECT A REASON',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Column(
                children: _kTerminateReasons.map((r) {
                  final selected = _selectedReason == r.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedReason = r.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0x12EF4444) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? const Color(0xFFEF4444) : c.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            r.icon,
                            size: 18,
                            color: selected ? const Color(0xFFEF4444) : c.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r.label,
                              style: TextStyle(
                                color: selected ? const Color(0xFFEF4444) : c.text,
                                fontSize: 14,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle, size: 18, color: Color(0xFFEF4444)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_selectedReason == 'other') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customReasonController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              maxLength: 300,
              style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Describe the issue…',
                hintStyle: TextStyle(color: c.textTertiary, fontFamily: 'Outfit'),
                filled: true,
                fillColor: c.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: (_canConfirm && !_terminating) ? _submit : null,
              child: Opacity(
                opacity: _canConfirm ? 1.0 : 0.45,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: _terminating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stop_circle, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Terminate Adda',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
