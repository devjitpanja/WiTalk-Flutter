import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/audio_room_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/audio_room/grid_seating_layout.dart';
import '../../widgets/audio_room/audio_room_bottom_bar.dart';
import '../../widgets/audio_room/room_rules_banner.dart';
import '../../widgets/audio_room/user_profile_bottom_sheet.dart';
import '../../widgets/audio_room/report_bottom_sheet.dart';

const Color _kBg = Color(0xFF0D1017);
const Color _kPrimary = Color(0xFF0751DF);
const Color _kGold = Color(0xFF5B9AFF);

class LiveAudioRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LiveAudioRoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<LiveAudioRoomScreen> createState() =>
      _LiveAudioRoomScreenState();
}

class _LiveAudioRoomScreenState extends ConsumerState<LiveAudioRoomScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _chatCtrl = TextEditingController();
  final _chatFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  // Floating reactions
  final List<_FloatingReaction> _reactions = [];

  // Animation controllers
  late AnimationController _pulseCtrl;

  bool _isRoomEnded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioRoomProvider.notifier).joinRoom(widget.roomId);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final notifier = ref.read(audioRoomProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App going to background — keep audio alive (socket stays connected)
      notifier.minimizeRoom();
    } else if (state == AppLifecycleState.resumed) {
      // App restored — re-request seat state to resync
      notifier.restoreRoom();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatCtrl.dispose();
    _chatFocus.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleEmptySeatPress(int seatIndex) {
    final s = ref.read(audioRoomProvider);
    final notifier = ref.read(audioRoomProvider.notifier);

    // Guard: seats not initialized yet
    if (!s.seatsInitialized) {
      _showSnack('Seats are still loading, please wait...');
      return;
    }

    // Guard: no permission to take seats
    if (!s.canTakeAddaSeat) {
      _showSnack("You don't have permission to take a seat.");
      return;
    }

    final isLocked = s.lockedSeats.contains(seatIndex);
    final isCommunityPrivileged =
        s.myCommunityRole == 'super_admin' || s.myCommunityRole == 'admin';
    final canBypassLock = s.isHost || s.isAdmin || isCommunityPrivileged;

    if (isLocked && !canBypassLock) {
      if (s.isHandRaised) {
        _showSnack('You already have a pending seat request');
      } else {
        notifier.toggleHandRaise();
        _showSnack('Seat request sent to the host');
      }
      return;
    }

    // If already in a different seat, switch seats
    if (s.isInSeat && s.currentSeatIndex != seatIndex) {
      notifier.changeSeat(s.currentSeatIndex, seatIndex);
      _showSnack('Moving to Seat #${seatIndex + 1}...');
      return;
    }

    // Take seat directly (no bottom sheet modal)
    notifier.takeSeat(seatIndex);
    _showSnack('Joining stage...');
  }

  void _showHandRaiseConfirm() {
    final s = ref.read(audioRoomProvider);
    if (s.isHandRaised) {
      // Already requested → cancel
      ref.read(audioRoomProvider.notifier).toggleHandRaise();
      _showSnack('Seat request cancelled');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoOnStageSheet(
        onConfirm: () {
          ref.read(audioRoomProvider.notifier).toggleHandRaise();
          _showSnack('Seat request sent');
        },
      ),
    );
  }

  void _handleGoOnStage() {
    final s = ref.read(audioRoomProvider);
    if (s.isHandRaised) {
      ref.read(audioRoomProvider.notifier).toggleHandRaise();
      _showSnack('Request cancelled');
    } else {
      ref.read(audioRoomProvider.notifier).toggleHandRaise();
      _showSnack('Hand raised — waiting for host');
    }
  }

  void _handleOffStage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: 'Leave Stage?',
        message: 'You will stop speaking and move to the audience.',
        confirmText: 'Leave Stage',
        confirmColor: const Color(0xFFFF6B6B),
        onConfirm: () => ref.read(audioRoomProvider.notifier).leaveSeat(),
      ),
    );
  }

  void _handleLeave() {
    final isHost = ref.read(audioRoomProvider).isHost;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: isHost ? 'End Room?' : 'Leave Room?',
        message: isHost
            ? 'Ending the room will disconnect all participants.'
            : 'Are you sure you want to leave?',
        confirmText: isHost ? 'End Room' : 'Leave',
        confirmColor: const Color(0xFFFF6B6B),
        onConfirm: () async {
          if (isHost) {
            ref.read(audioRoomProvider.notifier).endRoom();
          } else {
            await ref.read(audioRoomProvider.notifier).leaveRoom();
          }
          if (mounted) context.pop();
        },
      ),
    );
  }

  void _handleSendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(audioRoomProvider.notifier).sendChatMessage(text);
    _chatCtrl.clear();
    _chatFocus.unfocus();
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleShareRoom() {
    final s = ref.read(audioRoomProvider);
    Clipboard.setData(
        ClipboardData(text: 'Join my Adda "${s.roomName}": https://witalk.app/room/${widget.roomId}'));
    _showSnack('Room link copied to clipboard!');
  }

  void _triggerReaction(String emoji) {
    final rnd = math.Random();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _reactions.add(_FloatingReaction(
        id: id,
        emoji: emoji,
        x: 40 + rnd.nextDouble() * 240,
        y: 260 + rnd.nextDouble() * 160,
      ));
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _reactions.removeWhere((r) => r.id == id));
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A2340),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMoreOptions() {
    final s = ref.read(audioRoomProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoreOptionsSheet(
        isHost: s.isHost,
        isInSeat: s.isInSeat,
        handRaiseCount: s.handRaiseQueue.length,
        onOffStage: _handleOffStage,
        onViewRequests: () {
          Navigator.pop(context);
          _showSeatRequests();
        },
        onViewAudience: () {
          Navigator.pop(context);
          _showAudienceList();
        },
        onReaction: (e) {
          Navigator.pop(context);
          _triggerReaction(e);
          ref.read(audioRoomProvider.notifier).sendReaction(e);
        },
      ),
    );
  }

  void _showSeatRequests() {
    final queue = ref.read(audioRoomProvider).handRaiseQueue;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SeatRequestsSheet(
        queue: queue,
        onAccept: (uid) =>
            ref.read(audioRoomProvider.notifier).acceptSeatRequest(uid),
        onReject: (uid) =>
            ref.read(audioRoomProvider.notifier).rejectSeatRequest(uid),
      ),
    );
  }

  void _showAudienceList() {
    final audience = ref.read(audioRoomProvider).audience;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AudienceListSheet(audience: audience),
    );
  }

  // ── Provider-driven alert dialog ───────────────────────────────────────────
  void _showProviderAlertDialog(Map<String, dynamic> config) {
    final title = config['title']?.toString() ?? '';
    final message = config['message']?.toString() ?? '';
    final confirmLabel = config['confirmLabel']?.toString() ?? 'OK';
    final cancelLabel = config['cancelLabel']?.toString();
    final onConfirm = config['onConfirm'] as void Function()?;
    final onCancel = config['onCancel'] as void Function()?;

    showDialog(
      context: context,
      barrierDismissible: cancelLabel != null,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2340),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFEBEBF5),
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0x99EBEBF5),
            fontFamily: 'Outfit',
            fontSize: 14,
          ),
        ),
        actions: [
          if (cancelLabel != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onCancel?.call();
                ref.read(audioRoomProvider.notifier).hideAlertDialog();
              },
              child: Text(
                cancelLabel,
                style: const TextStyle(
                  color: Color(0x73EBEBF5),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm?.call();
              ref.read(audioRoomProvider.notifier).hideAlertDialog();
            },
            child: Text(
              confirmLabel,
              style: const TextStyle(
                color: _kPrimary,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) ref.read(audioRoomProvider.notifier).hideAlertDialog();
    });
  }

  // ── Seat invite dialog ────────────────────────────────────────────────────
  void _showSeatInviteDialog(Map<String, dynamic> invite) {
    final seatIndex = invite['seatIndex'] as int? ?? -1;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2340),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Stage Invitation',
          style: TextStyle(
            color: Color(0xFFEBEBF5),
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          seatIndex >= 0
              ? 'The host invited you to speak on seat ${seatIndex + 1}.'
              : 'The host invited you to speak on stage.',
          style: const TextStyle(
            color: Color(0x99EBEBF5),
            fontFamily: 'Outfit',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(audioRoomProvider.notifier).declineSeatInvite();
            },
            child: const Text(
              'Decline',
              style: TextStyle(color: Color(0x73EBEBF5), fontFamily: 'Outfit'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(audioRoomProvider.notifier).acceptSeatInvite();
            },
            child: const Text(
              'Accept',
              style: TextStyle(
                color: _kPrimary,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }



  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(audioRoomProvider);
    final myUid = ref.watch(authProvider).uid;

    // Auto-listen to state changes
    ref.listen<AudioRoomState>(audioRoomProvider, (prev, next) {
      if (!mounted) return;

      // Auto-scroll chat on new message
      if ((next.chatMessages.length) > (prev?.chatMessages.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }

      // Show alert dialog from provider state
      if (next.showAlertDialog &&
          !(prev?.showAlertDialog ?? false) &&
          next.alertDialogConfig != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showProviderAlertDialog(next.alertDialogConfig!);
        });
      }

      // Show seat invite dialog
      if (next.incomingSeatInvite != null &&
          prev?.incomingSeatInvite == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showSeatInviteDialog(next.incomingSeatInvite!);
        });
      }

      // Room ended screen (non-host)
      if (next.showRoomEndedScreen && !(prev?.showRoomEndedScreen ?? false)) {
        setState(() => _isRoomEnded = true);
      }

      // Host ended own room → just navigate back
      if (next.shouldNavigateBack && !(prev?.shouldNavigateBack ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      }

      // Kicked from room — show toast then navigate back
      if (next.kickedFromRoom && !(prev?.kickedFromRoom ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showSnack('You have been removed from this room by the host');
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) context.pop();
          });
        });
      }

      // Banned from room — show toast then navigate back
      if (next.bannedFromRoom && !(prev?.bannedFromRoom ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showSnack('You have been banned from this room by the host');
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) context.pop();
          });
        });
      }
    });

    // Loading state — either initial join or waiting for seat state sync
    if (roomState.isLoading || (!roomState.seatsInitialized && roomState.isConnected && roomState.error == null)) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _kPrimary),
              const SizedBox(height: 20),
              Text(
                roomState.isLoading ? 'Joining Adda...' : 'Syncing stage...',
                style: const TextStyle(
                  color: Color(0xCCEBEBF5),
                  fontSize: 16,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error / room ended state
    if (roomState.error != null || _isRoomEnded) {
      return _buildErrorScreen(roomState);
    }

    // Build the seats list from state
    final seatsList = _buildSeatsList(roomState, myUid);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────
              _buildHeader(roomState),

              // ── Fixed: stage grid + rules banner (never scrolls) ──
              GridSeatingLayout(
                seats: seatsList,
                maxSeats: roomState.maxSeats,
                hostUid: roomState.hostUid,
                myUid: myUid,
                activeSpeakerUid: roomState.activeSpeakerUid,
                stageRequestEnabled: roomState.stageRequestEnabled,
                isHost: roomState.isHost,
                seatsInitialized: roomState.seatsInitialized,
                audience: roomState.audience,
                onSpeakerTap: (speaker) => _showParticipantSheet(speaker),
                onEmptySeatTap: _handleEmptySeatPress,
                onEmptySeatLongPress: (idx) {
                  if (roomState.isHost) {
                    ref.read(audioRoomProvider.notifier).toggleSeatLock(idx);
                  }
                },
                onShowAudienceList: _showAudienceList,
                onAudienceMemberTap: (m) => _showParticipantSheet(m),
              ),

              if (roomState.roomRules != null &&
                  roomState.roomRules!.isNotEmpty &&
                  !roomState.rulesDismissed)
                RoomRulesBanner(
                  rulesText: roomState.roomRules!,
                  onDismiss: () =>
                      ref.read(audioRoomProvider.notifier).dismissRulesBanner(),
                ),

              // ── ADDA CHAT divider (fixed) ─────────────────────
              _buildAddaChatDivider(),

              // ── Scrollable chat + emoji strip ─────────────────
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(10, 4, 56, 16),
                      itemCount: roomState.chatMessages.length > 50
                          ? 50
                          : roomState.chatMessages.length,
                      itemBuilder: (_, i) {
                        final msgs = roomState.chatMessages.length > 50
                            ? roomState.chatMessages.sublist(
                                roomState.chatMessages.length - 50)
                            : roomState.chatMessages;
                        return _buildChatBubble(msgs[i]);
                      },
                    ),

                    // Vertical Emoji Reaction Strip on right side
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _buildEmojiReactionStrip(),
                    ),

                    // Floating reactions overlay
                    ..._reactions.map((r) => _buildFloatingReaction(r)),
                  ],
                ),
              ),

              // ── Bottom bar ────────────────────────────────
              AudioRoomBottomBar(
                isMicOn: !roomState.isMuted,
                isHost: roomState.isHost,
                isInSeat: roomState.isInSeat,
                hasPendingRequest: roomState.isHandRaised,
                stageRequestEnabled: roomState.stageRequestEnabled,
                audioOutputMode: roomState.audioOutputMode,
                chatController: _chatCtrl,
                chatFocusNode: _chatFocus,
                onToggleMic: () =>
                    ref.read(audioRoomProvider.notifier).toggleMic(),
                onToggleSpeaker: _showAudioOutputOptions,
                onGoOnStage: _handleGoOnStage,
                onOffStage: _handleOffStage,
                onMorePress: _showMoreOptions,
                onLeave: _handleLeave,
                onSendMessage: _handleSendChat,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(AudioRoomState s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0x0A0751DF), // rgba(7, 81, 223, 0.04)
        border: Border(
          bottom: BorderSide(color: Color(0x1F0751DF), width: 1), // rgba(7, 81, 223, 0.12)
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Minimize button
          GestureDetector(
            onTap: () {
              ref.read(audioRoomProvider.notifier).toggleMinimised();
              context.pop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x140751DF),
                border: Border.all(color: const Color(0x330751DF), width: 1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: _kPrimary,
                size: 26,
              ),
            ),
          ),

          // Center: Room name + badgeRow
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.roomName,
                  style: const TextStyle(
                    color: Color(0xFFEBEBF5),
                    fontSize: 17,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Color(0x590751DF),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // • Community / • Personal tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x26DC3C1E), // rgba(220, 60, 30, 0.15)
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x66DC501E)), // rgba(220, 80, 30, 0.4)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE84040),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            s.groupId != null ? 'Community' : 'Personal',
                            style: const TextStyle(
                              color: Color(0xFFFF7755),
                              fontSize: 9,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // • REC badge (if recording)
                    if (s.cloudRecordingActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x26EF4444), // rgba(239, 68, 68, 0.15)
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x66EF4444)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BlinkingRecDot(),
                            SizedBox(width: 5),
                            Text(
                              'REC',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 9,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Rating badge (if rating > 0)
                    if (s.averageRating != null && s.averageRating! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x1FFA726),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x59FFA726)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 9, color: Color(0xFFFFA726)),
                            const SizedBox(width: 4),
                            Text(
                              s.averageRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFFFFA726),
                                fontSize: 9,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Right: Share button
          GestureDetector(
            onTap: _handleShareRoom,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x140751DF),
                border: Border.all(color: const Color(0x330751DF), width: 1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.share,
                color: _kPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Divider: ADDA CHAT ──────────────────────────────────────────────
  Widget _buildAddaChatDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: const Color(0x1F0751DF))),
          const SizedBox(width: 6),
          const Icon(
            Icons.chat_bubble_outline,
            size: 11,
            color: Color(0x730751DF),
          ),
          const SizedBox(width: 4),
          const Text(
            'ADDA CHAT',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: Color(0x8C828CF8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 1, color: const Color(0x1F0751DF))),
        ],
      ),
    );
  }

  // ── Emoji Reaction Strip (Right Floating Column) ───────────────────────────
  Widget _buildEmojiReactionStrip() {
    final emojis = ['❤️', '👍', '👎', '👏', '😂', '😭', '😔', '🥺'];

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0x26000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                _triggerReaction(emoji);
                ref.read(audioRoomProvider.notifier).sendReaction(emoji);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Build seats list from state ────────────────────────────────────────────
  List<Map<String, dynamic>> _buildSeatsList(AudioRoomState s, String? myUid) {
    return List.generate(s.maxSeats, (index) {
      Map<String, dynamic>? occupant;
      for (final sp in s.speakers) {
        final spUid = sp['uid']?.toString().trim();
        if (sp['isEmpty'] != true && spUid != null && spUid.isNotEmpty && spUid != 'null') {
          if (sp['seatIndex'] == index) {
            occupant = sp;
            break;
          }
        }
      }

      if (occupant != null) {
        final uid = occupant['uid']?.toString() ?? '';
        final avatar = occupant['profile_pic']?.toString() ?? occupant['avatar']?.toString();
        return {
          'isEmpty': false,
          'uid': uid,
          'name': occupant['name']?.toString() ?? uid,
          'profile_pic': avatar,
          'avatar': avatar,
          'avatar_frame_url': (occupant['avatarFrameUrl'] ?? occupant['avatar_frame_url'])?.toString(),
          'isHost': uid == s.hostUid || occupant['isHost'] == true,
          'isAdmin': occupant['isAdmin'] == true,
          'communityRole': occupant['communityRole']?.toString(),
          'isVerified': occupant['isVerified'] == true,
          'isMuted': occupant['isMuted'] == true,
          'isSelf': uid == myUid,
          'seatIndex': index,
        };
      }

      final isLocked = s.lockedSeats.contains(index);

      return {
        'isEmpty': true,
        'seatIndex': index,
        'isLocked': isLocked,
      };
    });
  }

  // ── Chat messages ──────────────────────────────────────────────────────────
  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final bool isSystem = msg['isSystem'] == true ||
        msg['senderUid'] == 'system' ||
        msg['type'] == 'system' ||
        msg['senderName'] == 'System';
    final text = msg['text']?.toString() ?? msg['content']?.toString() ?? '';

    // System announcement bubble with Megaphone badge
    if (isSystem) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x260751DF),
                border: Border.all(color: const Color(0x4D0751DF)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.campaign,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x140751DF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x260751DF)),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xCCEBEBF5),
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final sender = (msg['sender_username'] ??
            msg['senderName'] ??
            msg['sender_name'] ??
            msg['username'] ??
            msg['name'] ??
            'User')
        .toString();
    final ts = msg['timestamp'];
    String time = '';
    if (ts is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    final senderPic = (msg['sender_profile_picture'] ??
            msg['senderAvatar'] ??
            msg['sender_avatar'] ??
            msg['profile_pic'] ??
            msg['avatar'])
        ?.toString();
    final isMe = msg['isSelf'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x1A0751DF),
              border: Border.all(color: const Color(0x330751DF), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: senderPic != null && senderPic.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: senderPic,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Center(
                      child: Text(
                        sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    placeholder: (_, __) => Center(
                      child: Text(
                        sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),

          // Bubble
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0x1A0751DF)
                        : const Color(0x1AFFFFFF),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                      bottomLeft: Radius.circular(2),
                    ),
                    border: Border.all(
                      color: isMe
                          ? const Color(0x260751DF)
                          : const Color(0x1AFFFFFF),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sender,
                            style: TextStyle(
                              color: isMe ? _kGold : const Color(0xFF5B9AFF),
                              fontSize: 11,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (time.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              time,
                              style: const TextStyle(
                                color: Color(0x4DFFFFFF),
                                fontSize: 9,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: const TextStyle(
                          color: Color(0xCCEBEBF5),
                          fontSize: 13,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Floating reaction ──────────────────────────────────────────────────────
  Widget _buildFloatingReaction(_FloatingReaction r) {
    return Positioned(
      left: r.x,
      top: r.y,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(seconds: 3),
        builder: (_, t, child) => Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -60 * t),
            child: child,
          ),
        ),
        child: Text(r.emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  // ── Error / Ended screen ───────────────────────────────────────────────────
  Widget _buildErrorScreen(AudioRoomState s) {
    final isJoinError = !s.isConnected && s.error != null;
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isJoinError ? Icons.wifi_off_rounded : Icons.event_busy,
                color: Colors.orange,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isJoinError ? 'Could Not Join Adda' : 'This Adda Has Ended',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isJoinError
                    ? (s.error ?? 'Unable to join this room. Please try again.')
                    : 'The host has wrapped up this room.\nCheck out other live addas.',
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  ref.read(audioRoomProvider.notifier).leaveRoom();
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Back to Addas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Participant profile sheet ───────────────────────────────────────────────
  void _showParticipantSheet(Map<String, dynamic> seat) {
    final s = ref.read(audioRoomProvider);
    final myUid = ref.read(authProvider).uid;
    final uid = seat['uid']?.toString() ?? '';
    final isSelf = uid == myUid;
    final isAuthority = s.isHost || s.isAdmin || s.isCoHost;

    // Ghost seat — host/admin can remove it
    final isGhost = seat['isEmpty'] != true &&
        (seat['name'] == null || seat['name'] == 'User' || seat['name'] == uid);
    if (isGhost && !isSelf && isAuthority) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A2340),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Unknown User in Seat',
              style: TextStyle(color: Color(0xFFEBEBF5), fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          content: const Text(
              'This seat has a disconnected user blocking the spot. Would you like to remove them?',
              style: TextStyle(color: Color(0x99EBEBF5), fontFamily: 'Outfit', fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0x73EBEBF5), fontFamily: 'Outfit')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(audioRoomProvider.notifier).removeGhostFromSeat(uid);
              },
              child: const Text('Remove',
                  style: TextStyle(color: Color(0xFFFF3B30), fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }

    // Map seat data to the shape UserProfileBottomSheet expects
    final participantData = {
      'userID': uid,
      'userName': seat['name']?.toString() ?? uid,
      'avatar': seat['profile_pic']?.toString() ?? seat['avatar']?.toString(),
      'avatar_frame_url': (seat['avatarFrameUrl'] ?? seat['avatar_frame_url'])?.toString(),
      'isHost': seat['isHost'] == true,
      'isAdmin': seat['isAdmin'] == true,
      'isMicOn': seat['isMuted'] != true,
      'communityRole': seat['communityRole']?.toString(),
      'isVerified': seat['isVerified'] == true,
    };

    final isParticipantInSeat = seat['isEmpty'] != true;

    showUserProfileBottomSheet(
      context: context,
      participant: participantData,
      isHost: isAuthority,
      isAdmin: s.isAdmin,
      currentUserId: myUid,
      hostUid: s.hostUid,
      isParticipantInSeat: isParticipantInSeat,
      isCommunityAdda: s.groupId != null,
      myCommunityRole: s.myCommunityRole,
      communityRolesMap: s.communityRolesMap,
      actionsFrozen: false,
      maxSeats: s.maxSeats,
      seatsState: s.speakers,
      onFollowHost: () {},
      onSetVolume: (userId, volume) =>
          ref.read(audioRoomProvider.notifier).setParticipantVolume(userId, volume),
      onMute: !isSelf && isAuthority
          ? (p) => ref.read(audioRoomProvider.notifier).muteParticipant(uid)
          : null,
      onUnmute: !isSelf && isAuthority
          ? (p) => ref.read(audioRoomProvider.notifier).requestUnmute(uid)
          : null,
      onKick: !isSelf && isAuthority
          ? (p) => ref.read(audioRoomProvider.notifier).kickParticipant(uid)
          : null,
      onOffStage: !isSelf && isAuthority && isParticipantInSeat
          ? (p) => ref.read(audioRoomProvider.notifier).offStageParticipant(uid)
          : null,
      onInviteToSeat: !isSelf && isAuthority && !isParticipantInSeat
          ? (p) => ref.read(audioRoomProvider.notifier).inviteToSeat(uid, -1)
          : null,
      onPromoteToAdmin: !isSelf && s.isHost
          ? (p) => ref.read(audioRoomProvider.notifier).promoteAdmin(uid)
          : null,
      onDemoteAdmin: !isSelf && s.isHost
          ? (p) => ref.read(audioRoomProvider.notifier).demoteAdmin(uid)
          : null,
      onMoveToSeat: !isSelf && isAuthority && isParticipantInSeat
          ? (p, seatIdx) => ref.read(audioRoomProvider.notifier).moveParticipantToSeat(uid, seatIdx)
          : null,
      onReportUser: !isSelf
          ? (p, canBan) {
              showReportBottomSheet(
                context: context,
                participant: participantData,
                canBan: canBan,
                onBanUser: (p2, reason) =>
                    ref.read(audioRoomProvider.notifier).banParticipant(uid),
              );
            }
          : null,
      onCommunityKick: !isSelf && isAuthority
          ? (p, reason) {
              final name = seat['name']?.toString() ?? uid;
              ref.read(audioRoomProvider.notifier).communityKick(uid, name, reason: reason);
            }
          : null,
      onCommunityBan: !isSelf && isAuthority
          ? (p, reason) {
              final name = seat['name']?.toString() ?? uid;
              ref.read(audioRoomProvider.notifier).communityBan(uid, name, reason: reason);
            }
          : null,
    );
  }

  // ── Audio output options ───────────────────────────────────────────────────
  void _showAudioOutputOptions() {
    final s = ref.read(audioRoomProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AudioOutputSheet(
        currentMode: s.audioOutputMode,
        bluetoothAvailable: s.isBluetoothAvailable,
        onSelect: (mode) {
          ref.read(audioRoomProvider.notifier).setAudioOutputMode(mode);
        },
      ),
    );
  }
}

// ── Blinking REC dot widget ──────────────────────────────────────────────────
class _BlinkingRecDot extends StatefulWidget {
  const _BlinkingRecDot();

  @override
  State<_BlinkingRecDot> createState() => _BlinkingRecDotState();
}

class _BlinkingRecDotState extends State<_BlinkingRecDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }
}

// ── Floating reaction data ─────────────────────────────────────────────────────
class _FloatingReaction {
  final String id, emoji;
  final double x, y;
  const _FloatingReaction(
      {required this.id, required this.emoji, required this.x, required this.y});
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheets
// ─────────────────────────────────────────────────────────────────────────────

class _GoOnStageSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  const _GoOnStageSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('🎤', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'Request to Go On Stage',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Raise your hand and the host will place you on stage.',
            style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14, fontFamily: 'Outfit'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0751DF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Raise Hand ✋',
                style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final String title, message, confirmText;
  final Color confirmColor;
  final VoidCallback onConfirm;
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 14, fontFamily: 'Outfit'), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmText, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreOptionsSheet extends StatelessWidget {
  final bool isHost;
  final bool isInSeat;
  final int handRaiseCount;
  final VoidCallback? onOffStage;
  final VoidCallback? onViewRequests;
  final VoidCallback? onViewAudience;
  final void Function(String emoji)? onReaction;

  const _MoreOptionsSheet({
    required this.isHost,
    required this.isInSeat,
    required this.handRaiseCount,
    this.onOffStage,
    this.onViewRequests,
    this.onViewAudience,
    this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final emojis = ['❤️', '👍', '👎', '👏', '😂', '😭', '😔', '🥺'];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Reactions row
          const Text('Reactions', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12, fontFamily: 'Outfit')),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((e) => GestureDetector(
              onTap: () => onReaction?.call(e),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x1A0751DF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x330751DF)),
                ),
                alignment: Alignment.center,
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0x1AFFFFFF)),
          const SizedBox(height: 8),
          // Options list
          if (isInSeat)
            _optionTile(
              icon: Icons.person_remove_outlined,
              label: 'Leave Stage',
              color: const Color(0xFFFF6B6B),
              onTap: () { Navigator.pop(context); onOffStage?.call(); },
            ),
          _optionTile(
            icon: Icons.people_outline,
            label: 'View Audience',
            onTap: onViewAudience,
          ),
          if (isHost && handRaiseCount > 0)
            _optionTile(
              icon: Icons.pan_tool_outlined,
              label: 'Seat Requests ($handRaiseCount)',
              color: const Color(0xFFFF9800),
              onTap: onViewRequests,
            ),
        ],
      ),
    );
  }

  Widget _optionTile({required IconData icon, required String label, Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(label, style: TextStyle(color: color ?? Colors.white, fontFamily: 'Outfit', fontSize: 14)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _SeatRequestsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> queue;
  final void Function(String uid) onAccept;
  final void Function(String uid) onReject;
  const _SeatRequestsSheet({required this.queue, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const Text('Seat Requests', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (queue.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No pending requests', style: TextStyle(color: Color(0x66FFFFFF), fontFamily: 'Outfit')),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: queue.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0x1AFFFFFF), height: 1),
                itemBuilder: (_, i) {
                  final req = queue[i];
                  final uid = req['uid']?.toString() ?? '';
                  final name = req['name']?.toString() ?? uid;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0x1A0751DF),
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF34C759), size: 28),
                          onPressed: () { Navigator.pop(context); onAccept(uid); },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF3B30), size: 28),
                          onPressed: () { Navigator.pop(context); onReject(uid); },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AudienceListSheet extends StatelessWidget {
  final List<Map<String, dynamic>> audience;
  const _AudienceListSheet({required this.audience});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          Text('Audience (${audience.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (audience.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No audience members yet', style: TextStyle(color: Color(0x66FFFFFF), fontFamily: 'Outfit')),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: audience.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0x1AFFFFFF), height: 1),
                itemBuilder: (_, i) {
                  final m = audience[i];
                  final name = m['name']?.toString() ?? m['uid']?.toString() ?? 'User';
                  final pic = m['profile_pic']?.toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x1A0751DF),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (pic != null && pic.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: pic,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                              ),
                              placeholder: (_, __) => Center(
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                              ),
                            )
                          : Center(
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                            ),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit')),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}


class _AudioOutputSheet extends StatelessWidget {
  final String currentMode;
  final bool bluetoothAvailable;
  final void Function(String mode) onSelect;
  const _AudioOutputSheet({
    required this.currentMode,
    required this.onSelect,
    this.bluetoothAvailable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const Text('Audio Output', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _audioOption(context, 'speaker', Icons.volume_up, 'Loudspeaker'),
          _audioOption(context, 'earpiece', Icons.hearing, 'Earpiece'),
          if (bluetoothAvailable)
            _audioOption(context, 'bluetooth', Icons.bluetooth_audio, 'Bluetooth'),
        ],
      ),
    );
  }

  Widget _audioOption(BuildContext context, String mode, IconData icon, String label) {
    final isSelected = currentMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF0751DF) : Colors.white70),
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF0751DF) : Colors.white, fontFamily: 'Outfit')),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF0751DF)) : null,
      onTap: () { Navigator.pop(context); onSelect(mode); },
      contentPadding: EdgeInsets.zero,
    );
  }
}
