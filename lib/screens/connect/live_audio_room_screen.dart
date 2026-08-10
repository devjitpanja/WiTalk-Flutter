import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livekit_client/livekit_client.dart' show VideoTrack, VideoTrackRenderer, VideoViewMirrorMode, TrackSource;
import 'package:youtube_player_flutter/youtube_player_flutter.dart' show YoutubePlayerController, YoutubePlayerFlags, YoutubePlayer, PlayerState;
import '../../providers/audio_room_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/livekit_audio_manager.dart';
import '../../services/ban_check_service.dart';
import '../../widgets/audio_room/grid_seating_layout.dart';
import '../../widgets/common/share_bottom_sheet.dart';
import '../../widgets/audio_room/audio_room_bottom_bar.dart';
import '../../widgets/audio_room/room_rules_banner.dart';
import '../../widgets/audio_room/user_profile_bottom_sheet.dart';
import '../../widgets/audio_room/report_bottom_sheet.dart';
import '../../widgets/audio_room/more_options_bottom_sheet.dart';
import '../../widgets/audio_room/youtube_picker_bottom_sheet.dart';
import '../../widgets/audio_room/chat_gpt_bottom_sheet.dart';
import '../../widgets/audio_room/google_ai_bottom_sheet.dart';
import '../../widgets/audio_room/ask_ai_bottom_sheet.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kBg = Color(0xFF080C17);
const Color _kSurface = Color(0xFF0D1220);
const Color _kCard = Color(0xFF121930);
const Color _kPrimary = Color(0xFF2563EB);
const Color _kPrimaryGlow = Color(0x332563EB);

class LiveAudioRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final bool isHost;
  final bool restore;
  const LiveAudioRoomScreen({super.key, required this.roomId, this.isHost = false, this.restore = false});

  @override
  ConsumerState<LiveAudioRoomScreen> createState() =>
      _LiveAudioRoomScreenState();
}

class _LiveAudioRoomScreenState extends ConsumerState<LiveAudioRoomScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _chatCtrl = TextEditingController();
  final _chatFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  final List<_FloatingReaction> _reactions = [];
  late AnimationController _pulseCtrl;
  bool _isRoomEnded = false;

  // ── ChatGPT / Google AI state (mirrors RN) ──────────────────────────────────
  bool _showChatGPT = false;
  bool _showGoogleAI = false;
  String? _googleAIQuery;   // pre-filled query from "Ask AI" chat context menu
  bool _showAskAI = false;
  Map<String, dynamic>? _askAIMessage; // selected chat message for AskAI sheet

  // Admin feature flags (loaded from settings in RN; default true in Flutter)
  bool _chatgptFeatureEnabled = true;
  bool _googleAiFeatureEnabled = true;

  // ── YouTube player ──────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;
  bool _youtubeControlsVisible = true;
  Timer? _youtubeControlsHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Register cleanup hook so BanCheckService can leave/end the room
    // before wiping credentials on a platform ban.
    BanCheckService.registerPreLogoutHandler(() async {
      await ref.read(audioRoomProvider.notifier).leaveRoom();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(audioRoomProvider.notifier);
      if (widget.restore) {
        notifier.restoreRoom();
      } else {
        notifier.joinRoom(widget.roomId, isHost: widget.isHost);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final notifier = ref.read(audioRoomProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      notifier.minimizeRoom();
    } else if (state == AppLifecycleState.resumed) {
      notifier.restoreRoom();
    }
  }

  @override
  void dispose() {
    BanCheckService.unregisterPreLogoutHandler();
    WidgetsBinding.instance.removeObserver(this);
    _chatCtrl.dispose();
    _chatFocus.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _youtubeControlsHideTimer?.cancel();
    _ytController?.dispose();
    super.dispose();
  }

  // ── YouTube helpers ─────────────────────────────────────────────────────────

  void _initYoutubeController(String videoId, {double startAt = 0}) {
    _ytController?.dispose();
    _ytController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        startAt: startAt.toInt(),
        forceHD: false,
        enableCaption: false,
      ),
    )..addListener(_onYoutubePlayerUpdate);
    setState(() {});
  }

  void _onYoutubePlayerUpdate() {
    if (_ytController == null) return;
    final notifier = ref.read(audioRoomProvider.notifier);
    final player = _ytController!;

    if (!player.value.isReady) return;
    final isBuffering = player.value.playerState == PlayerState.buffering;
    notifier.updateYoutubeTime(player.value.position.inSeconds.toDouble());
    notifier.setYoutubeBuffering(isBuffering);
  }

  void _resetYoutubeControlsHideTimer() {
    _youtubeControlsHideTimer?.cancel();
    setState(() => _youtubeControlsVisible = true);
    _youtubeControlsHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _youtubeControlsVisible = false);
    });
  }

  void _handleYoutubeOptionPress(AudioRoomState s) {
    if (s.showYoutubeSection || s.youtubeVideoId != null) {
      // Stop YouTube
      ref.read(audioRoomProvider.notifier).stopYoutube();
      _ytController?.dispose();
      _ytController = null;
    } else {
      // Open picker (host/admin only)
      if (!s.isHost && !s.isAdmin) return;
      YouTubePickerBottomSheet.show(
        context,
        onSelectVideo: (videoId) {
          ref.read(audioRoomProvider.notifier).selectYoutubeVideo(videoId);
        },
      );
    }
  }

  void _showYoutubeFullscreen() {
    if (_ytController == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) {
        final ctrl = YoutubePlayerController(
          initialVideoId: _ytController!.metadata.videoId.isNotEmpty
              ? _ytController!.metadata.videoId
              : '',
          flags: YoutubePlayerFlags(
            autoPlay: true,
            startAt: _ytController!.value.position.inSeconds,
          ),
        );
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(child: YoutubePlayer(controller: ctrl, aspectRatio: 16 / 9)),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 12,
                child: GestureDetector(
                  onTap: () { ctrl.dispose(); Navigator.pop(context); },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleYoutubePlayPause(AudioRoomState s) {
    if (!s.isHost && !s.isAdmin) return;
    final ts = _ytController?.value.position.inSeconds.toDouble() ?? s.youtubeCurrentTime;
    if (s.youtubeIsPlaying) {
      // Pause locally first, then emit to others
      _ytController?.pause();
      ref.read(audioRoomProvider.notifier).pauseYoutube(ts);
    } else {
      // Play locally first, then emit to others
      _ytController?.play();
      ref.read(audioRoomProvider.notifier).playYoutube(ts);
    }
  }

  // ── Business logic ──────────────────────────────────────────────────────────

  void _handleEmptySeatPress(int seatIndex) {
    final s = ref.read(audioRoomProvider);
    final notifier = ref.read(audioRoomProvider.notifier);

    if (!s.seatsInitialized) {
      _showSnack('Seats are still loading, please wait...');
      return;
    }
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

    if (s.isInSeat && s.currentSeatIndex != seatIndex) {
      notifier.changeSeat(s.currentSeatIndex, seatIndex);
      _showSnack('Moving to Seat #${seatIndex + 1}...');
      return;
    }

    notifier.takeSeat(seatIndex);
    _showSnack('Joining stage...');
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
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: 'Leave Stage?',
        message: 'You will stop speaking and move to the audience.',
        confirmText: 'Leave Stage',
        confirmColor: const Color(0xFFEF4444),
        onConfirm: () => ref.read(audioRoomProvider.notifier).leaveSeat(),
      ),
    );
  }

  void _handleLeave() {
    final isHost = ref.read(audioRoomProvider).isHost;
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: isHost ? 'End Room?' : 'Leave Room?',
        message: isHost
            ? 'Ending the room will disconnect all participants.'
            : 'Are you sure you want to leave?',
        confirmText: isHost ? 'End Room' : 'Leave',
        confirmColor: const Color(0xFFEF4444),
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
    showShareBottomSheet(
      context,
      shareType: ShareType.adda,
      addaData: ShareAddaData(
        roomId: widget.roomId,
        roomName: s.roomName,
        hostUid: s.hostUid,
        inviteToken: s.roomInviteToken,
        isPublic: s.isPublic,
      ),
    );
  }

  void _triggerReaction(String emoji) {
    final rnd = math.Random();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _reactions.add(_FloatingReaction(
        id: id,
        emoji: emoji,
        x: 40 + rnd.nextDouble() * 220,
        y: 240 + rnd.nextDouble() * 140,
      ));
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _reactions.removeWhere((r) => r.id == id));
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xEEEBEBF5),
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A2236),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        elevation: 8,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMoreOptions() {
    final s = ref.read(audioRoomProvider);
    final isHostOrAdmin = s.isHost || s.isAdmin;

    final isYoutubeActive = s.showYoutubeSection || s.youtubeVideoId != null;
    final screenShareBlocked = s.isCameraSharing || s.cameraShareInfos.isNotEmpty || isYoutubeActive;
    final cameraBlocked = s.isScreenSharing || s.screenShareInfo != null || isYoutubeActive;
    final youtubeBlocked = s.isScreenSharing || s.screenShareInfo != null || s.isCameraSharing || s.cameraShareInfos.isNotEmpty;
    final activeCameraCount = (s.isCameraSharing ? 1 : 0) + s.cameraShareInfos.length;

    showMoreOptionsBottomSheet(
      context: context,
      isHost: isHostOrAdmin,
      isScreenSharing: s.isScreenSharing,
      isCameraSharing: s.isCameraSharing,
      activeCameraCount: activeCameraCount,
      onToggleScreenShare: () {
        ref.read(audioRoomProvider.notifier).toggleScreenShare();
      },
      onToggleCameraShare: () {
        ref.read(audioRoomProvider.notifier).toggleCameraShare();
      },
      screenShareBlocked: screenShareBlocked,
      cameraBlocked: cameraBlocked,
      youtubeBlocked: youtubeBlocked,
      screenShareFeatureEnabled: true,
      videoShareFeatureEnabled: true,
      youtubeFeatureEnabled: true,
      chatgptFeatureEnabled: _chatgptFeatureEnabled,
      googleAiFeatureEnabled: _googleAiFeatureEnabled,
      isYoutubeActive: isYoutubeActive,
      onYoutubeVideo: () => _handleYoutubeOptionPress(s),
      onChatGPT: _handleChatGPTPress,
      onGoogleAI: _handleGoogleAIPress,
      onRoomSettings: isHostOrAdmin ? _showRoomSettingsSheet : null,
      handRaiseCount: s.handRaiseQueue.length,
      onViewRequests: isHostOrAdmin && s.handRaiseQueue.isNotEmpty ? _showSeatRequests : null,
    );
  }

  void _showRoomSettingsSheet() {
    _showSnack('Room settings');
  }

  void _showSeatRequests() {
    final queue = ref.read(audioRoomProvider).handRaiseQueue;
    showModalBottomSheet(
      useRootNavigator: true,
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
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AudienceListSheet(audience: audience),
    );
  }

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
        backgroundColor: _kCard,
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
                    color: Color(0x73EBEBF5), fontFamily: 'Outfit'),
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
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) ref.read(audioRoomProvider.notifier).hideAlertDialog();
    });
  }

  void _showSeatInviteDialog(Map<String, dynamic> invite) {
    final seatIndex = invite['seatIndex'] as int? ?? -1;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
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
              color: Color(0x99EBEBF5), fontFamily: 'Outfit', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(audioRoomProvider.notifier).declineSeatInvite();
            },
            child: const Text('Decline',
                style: TextStyle(
                    color: Color(0x73EBEBF5), fontFamily: 'Outfit')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(audioRoomProvider.notifier).acceptSeatInvite();
            },
            child: const Text('Accept',
                style: TextStyle(
                    color: _kPrimary,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700)),
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

    ref.listen<AudioRoomState>(audioRoomProvider, (prev, next) {
      if (!mounted) return;

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

      if (next.showAlertDialog &&
          !(prev?.showAlertDialog ?? false) &&
          next.alertDialogConfig != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showProviderAlertDialog(next.alertDialogConfig!);
        });
      }

      if (next.incomingSeatInvite != null && prev?.incomingSeatInvite == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showSeatInviteDialog(next.incomingSeatInvite!);
        });
      }

      if (next.showRoomEndedScreen && !(prev?.showRoomEndedScreen ?? false)) {
        setState(() => _isRoomEnded = true);
      }

      if (next.shouldNavigateBack && !(prev?.shouldNavigateBack ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      }

      if (next.kickedFromRoom && !(prev?.kickedFromRoom ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showSnack('You have been removed from this room by the host');
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) context.pop();
          });
        });
      }

      if (next.bannedFromRoom && !(prev?.bannedFromRoom ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showSnack('You have been banned from this room by the host');
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) context.pop();
          });
        });
      }

      // ── React to YouTube state changes from socket ──────────────────────────
      final wasYt = prev?.youtubeVideoId;
      final nowYt = next.youtubeVideoId;
      if (wasYt != nowYt) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (nowYt != null && nowYt.isNotEmpty) {
            _initYoutubeController(nowYt, startAt: next.youtubeCurrentTime);
            _resetYoutubeControlsHideTimer();
          } else {
            _ytController?.dispose();
            _ytController = null;
            _youtubeControlsHideTimer?.cancel();
            setState(() {});
          }
        });
      }

      // Non-host: react to yt_play / yt_pause / yt_seek from socket
      // Host controls the player directly — no feedback from state to player for host
      if (!(next.isHost || next.isAdmin) && _ytController != null) {
        // yt_play received
        if (next.youtubeIsPlaying && !(prev?.youtubeIsPlaying ?? false)) {
          _ytController!.play();
          // Seek to synced position on play (handles late-joiner resync)
          if (next.youtubeCurrentTime > 1) {
            _ytController!.seekTo(Duration(seconds: next.youtubeCurrentTime.toInt()));
          }
        }
        // yt_pause received
        if (!next.youtubeIsPlaying && (prev?.youtubeIsPlaying ?? false)) {
          _ytController!.pause();
          if (next.youtubeCurrentTime > 0) {
            Future.delayed(const Duration(milliseconds: 100), () {
              _ytController?.seekTo(Duration(seconds: next.youtubeCurrentTime.toInt()));
            });
          }
        }
        // yt_seek received: large time jump while playing (not caused by normal play progress)
        final timeDelta = (next.youtubeCurrentTime - (prev?.youtubeCurrentTime ?? 0)).abs();
        final wasPlaying = prev?.youtubeIsPlaying ?? false;
        final playStateUnchanged = next.youtubeIsPlaying == wasPlaying;
        if (playStateUnchanged && timeDelta > 3) {
          _ytController!.seekTo(Duration(seconds: next.youtubeCurrentTime.toInt()));
        }
      }
    });

    // ── Loading state ──────────────────────────────────────────────────────
    if (roomState.isLoading ||
        (!roomState.seatsInitialized &&
            roomState.isConnected &&
            roomState.error == null)) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: _kPrimary,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                roomState.isLoading ? 'Joining Adda...' : 'Syncing stage...',
                style: const TextStyle(
                  color: Color(0xAAEBEBF5),
                  fontSize: 15,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Error / Ended ──────────────────────────────────────────────────────
    if (roomState.error != null || _isRoomEnded) {
      return _buildErrorScreen(roomState);
    }

    final seatsList = _buildSeatsList(roomState, myUid);
    final isYoutubeActive = roomState.showYoutubeSection || roomState.youtubeVideoId != null;
    final isScreenShareActive = roomState.isScreenSharing || roomState.screenShareInfo != null;
    final isCameraShareActive = roomState.isCameraSharing || roomState.cameraShareInfos.isNotEmpty;
    final hasAnyShare = roomState.isScreenSharing || roomState.isCameraSharing;

    // compact grid when any sharing is active (but no camera panel — camera replaces grid)
    final compactGrid = isYoutubeActive || isScreenShareActive;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _kBg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
            children: [
              // ── Header ─────────────────────────────────────
              _buildHeader(roomState),

              // ── YouTube section ─────────────────────────────
              if (isYoutubeActive) _buildYoutubeSection(roomState),

              // ── Screen share section ─────────────────────────
              if (isScreenShareActive) _buildScreenShareSection(roomState),

              // ── Camera share section (replaces seats) ────────
              if (isCameraShareActive)
                _buildCameraShareSection(roomState, seatsList, myUid)
              else ...[
                // ── Stage + rules (normal grid) ──────────────
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
                  compact: compactGrid,
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
              ],

              if (roomState.roomRules != null &&
                  roomState.roomRules!.isNotEmpty &&
                  !roomState.rulesDismissed)
                RoomRulesBanner(
                  rulesText: roomState.roomRules!,
                  onDismiss: () =>
                      ref.read(audioRoomProvider.notifier).dismissRulesBanner(),
                ),

              // ── Chat divider ────────────────────────────────
              _buildChatDivider(),

              // ── Scrollable chat + emoji strip ───────────────
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(10, 6, 56, 16),
                      itemCount: roomState.chatMessages.length > 50
                          ? 50
                          : roomState.chatMessages.length,
                      itemBuilder: (_, i) {
                        final msgs = roomState.chatMessages.length > 50
                            ? roomState.chatMessages
                                .sublist(roomState.chatMessages.length - 50)
                            : roomState.chatMessages;
                        return _buildChatBubble(msgs[i]);
                      },
                    ),

                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _buildEmojiStrip(),
                    ),

                    ..._reactions.map((r) => _buildFloatingReaction(r)),
                  ],
                ),
              ),

              // ── Bottom bar ─────────────────────────────────
              AudioRoomBottomBar(
                isMicOn: !roomState.isMuted,
                isHost: roomState.isHost,
                isInSeat: roomState.isInSeat,
                hasPendingRequest: roomState.isHandRaised,
                stageRequestEnabled: roomState.stageRequestEnabled,
                audioOutputMode: roomState.audioOutputMode,
                hasActiveShare: hasAnyShare,
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

        // ── ChatGPT overlay (persistent, slides in/out) ──────────────
        ChatGPTBottomSheet(
          visible: _showChatGPT,
          roomContext: 'Room: ${roomState.roomName}',
          onMinimize: () => setState(() => _showChatGPT = false),
          onClose: () => setState(() => _showChatGPT = false),
        ),

        // ── Google AI overlay (persistent, slides in/out) ────────────
        GoogleAIBottomSheet(
          visible: _showGoogleAI,
          roomContext: 'Room: ${roomState.roomName}',
          initialQuery: _googleAIQuery,
          onMinimize: () => setState(() {
            _showGoogleAI = false;
            _googleAIQuery = null;
          }),
          onClose: () => setState(() {
            _showGoogleAI = false;
            _googleAIQuery = null;
          }),
        ),

        // ── Ask AI sheet (shown via long-press on chat message) ───────
        if (_showAskAI && _askAIMessage != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() {
                _showAskAI = false;
                _askAIMessage = null;
              }),
              behavior: HitTestBehavior.opaque,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {}, // absorb taps inside sheet
                  child: AskAIBottomSheet(
                    message: (_askAIMessage!['text'] ??
                            _askAIMessage!['content'] ??
                            '')
                        .toString(),
                    onAskGemini: (prompt) {
                      setState(() {
                        _showAskAI = false;
                        _askAIMessage = null;
                      });
                      _handleAskGemini(prompt);
                    },
                    onClose: () => setState(() {
                      _showAskAI = false;
                      _askAIMessage = null;
                    }),
                  ),
                ),
              ),
            ),
          ),
      ],
        ),
      ),
    );
  }

  // ── YouTube section ────────────────────────────────────────────────────────
  Widget _buildYoutubeSection(AudioRoomState s) {
    final screenWidth = MediaQuery.of(context).size.width;
    final playerHeight = (screenWidth * 9 / 16).roundToDouble();
    final isHostOrAdmin = s.isHost || s.isAdmin;

    return GestureDetector(
      onTap: () {
        _resetYoutubeControlsHideTimer();
        setState(() => _youtubeControlsVisible = !_youtubeControlsVisible);
      },
      child: Container(
        width: screenWidth,
        height: playerHeight,
        color: Colors.black,
        child: Stack(
          children: [
            // Player
            if (_ytController != null)
              YoutubePlayer(
                controller: _ytController!,
                showVideoProgressIndicator: false,
              )
            else
              Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Color(0xFFFF0000)),
              ),

            // Transparent overlay (captures taps for controls toggle)
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),

            // Controls overlay
            if (_youtubeControlsVisible)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _youtubeControlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.40),
                    child: Column(
                      children: [
                        // Top row: buffering + fullscreen
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              if (s.youtubeIsBuffering)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white70),
                                ),
                              const Spacer(),
                              if (isHostOrAdmin) ...[
                                // Change video
                                GestureDetector(
                                  onTap: () {
                                    YouTubePickerBottomSheet.show(
                                      context,
                                      onSelectVideo: (videoId) {
                                        ref.read(audioRoomProvider.notifier).selectYoutubeVideo(videoId);
                                      },
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Outfit')),
                                  ),
                                ),
                                // Stop
                                GestureDetector(
                                  onTap: () {
                                    ref.read(audioRoomProvider.notifier).stopYoutube();
                                    _ytController?.dispose();
                                    _ytController = null;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3B30).withValues(alpha: 0.80),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Stop', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                              // Fullscreen
                              GestureDetector(
                                onTap: () {
                                  if (_ytController != null) {
                                    _showYoutubeFullscreen();
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.fullscreen, color: Colors.white, size: 22),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Center play/pause (host only)
                        if (isHostOrAdmin)
                          GestureDetector(
                            onTap: () => _handleYoutubePlayPause(s),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                s.youtubeIsPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),

                        const Spacer(),

                        // Seek slider (host only)
                        if (isHostOrAdmin && s.youtubeDuration > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Text(
                                  _formatDuration(s.youtubeCurrentTime),
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Outfit'),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      trackHeight: 2,
                                      activeTrackColor: const Color(0xFFFF0000),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      overlayShape: SliderComponentShape.noOverlay,
                                    ),
                                    child: Slider(
                                      value: s.youtubeCurrentTime.clamp(0, s.youtubeDuration),
                                      min: 0,
                                      max: s.youtubeDuration,
                                      onChanged: (v) {
                                        _ytController?.seekTo(Duration(seconds: v.toInt()));
                                        ref.read(audioRoomProvider.notifier).seekYoutube(v);
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(s.youtubeDuration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Outfit'),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  // ── Screen share section ────────────────────────────────────────────────────
  Widget _buildScreenShareSection(AudioRoomState s) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Local sharer sees "Broadcasting" banner
    if (s.isScreenSharing) {
      return Container(
        width: screenWidth,
        height: 60,
        color: const Color(0xFF0D1220),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.screen_share, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'You are broadcasting your screen',
                style: TextStyle(color: Color(0xFFEBEBF5), fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: () => ref.read(audioRoomProvider.notifier).toggleScreenShare(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.4)),
                ),
                child: const Text('Stop', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    }

    // Remote screen share: show video feed
    final shareInfo = s.screenShareInfo;
    if (shareInfo == null) return const SizedBox.shrink();

    final uid = shareInfo['uid']?.toString() ?? '';
    final userName = shareInfo['userName']?.toString() ?? 'User';

    final vtv = s.videoTrackVersion;
    final videoTrack = uid.isNotEmpty
        ? liveKitAudioManager.getRemoteVideoTrack(uid)
        : null;

    return GestureDetector(
      onTap: () => _showScreenShareFullscreen(videoTrack, userName),
      child: Container(
        width: screenWidth,
        height: 160,
        color: Colors.black,
        child: Stack(
          children: [
            if (videoTrack != null)
              Positioned.fill(
                child: _RemoteVideoView(
                  key: ValueKey('screen_${uid}_$vtv'),
                  track: videoTrack,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.screen_share, color: Color(0xFF2563EB), size: 32),
                    const SizedBox(height: 6),
                    Text('$userName is sharing their screen',
                        style: const TextStyle(color: Colors.white70, fontFamily: 'Outfit', fontSize: 12)),
                  ],
                ),
              ),
            // Tap hint
            const Positioned(
              right: 8,
              bottom: 6,
              child: Icon(Icons.fullscreen, color: Colors.white54, size: 18),
            ),
            // Label
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(userName,
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Outfit')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScreenShareFullscreen(VideoTrack? track, String userName) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (track != null)
              Center(child: _RemoteVideoView(key: ValueKey('fs_screen'), track: track))
            else
              const Center(child: Icon(Icons.screen_share, color: Colors.white54, size: 60)),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Camera share section ────────────────────────────────────────────────────
  Widget _buildCameraShareSection(AudioRoomState s, List<Map<String, dynamic>> seats, String? myUid) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelHeight = (MediaQuery.of(context).size.height * 0.30).roundToDouble();

    return SizedBox(
      width: screenWidth,
      height: panelHeight,
      child: Stack(
        children: [
          // Background: camera video feeds fill panel
          Positioned.fill(
            child: _buildCameraFeeds(s),
          ),

          // Horizontal seat grid overlaid at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GridSeatingLayout(
                seats: seats,
                maxSeats: s.maxSeats,
                hostUid: s.hostUid,
                myUid: myUid,
                activeSpeakerUid: s.activeSpeakerUid,
                stageRequestEnabled: s.stageRequestEnabled,
                isHost: s.isHost,
                seatsInitialized: s.seatsInitialized,
                audience: s.audience,
                compact: true,
                horizontal: true,
                hideAudience: true,
                onSpeakerTap: (speaker) => _showParticipantSheet(speaker),
                onEmptySeatTap: _handleEmptySeatPress,
                onEmptySeatLongPress: (idx) {
                  if (s.isHost) {
                    ref.read(audioRoomProvider.notifier).toggleSeatLock(idx);
                  }
                },
              ),
            ),
          ),

          // Camera flip + stop button for local sharer
          if (s.isCameraSharing)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _CamControl(
                    icon: Icons.flip_camera_ios,
                    onTap: () => ref.read(audioRoomProvider.notifier).switchCameraFacing(),
                  ),
                  const SizedBox(width: 8),
                  _CamControl(
                    icon: Icons.videocam_off,
                    color: const Color(0xFFFF3B30),
                    onTap: () => ref.read(audioRoomProvider.notifier).toggleCameraShare(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraFeeds(AudioRoomState s) {
    final feeds = <Widget>[];

    final vtv = s.videoTrackVersion;

    // Local camera
    if (s.isCameraSharing) {
      final localTrack = liveKitAudioManager.localCameraTrack;
      feeds.add(
        localTrack != null
            ? _RemoteVideoView(key: ValueKey('local_cam_$vtv'), track: localTrack, mirror: true)
            : Container(color: Colors.black, alignment: Alignment.center,
                child: const Icon(Icons.videocam, color: Colors.white54, size: 32)),
      );
    }

    // Remote camera feeds
    for (final info in s.cameraShareInfos) {
      final uid = info['uid']?.toString() ?? '';
      final track = uid.isNotEmpty
          ? liveKitAudioManager.getRemoteVideoTrack(uid, source: TrackSource.camera)
          : null;
      feeds.add(
        track != null
            ? _RemoteVideoView(key: ValueKey('cam_${uid}_$vtv'), track: track)
            : Container(color: const Color(0xFF111828), alignment: Alignment.center,
                child: const Icon(Icons.videocam, color: Colors.white38, size: 28)),
      );
    }

    if (feeds.isEmpty) {
      return Container(color: Colors.black);
    }
    if (feeds.length == 1) {
      return feeds[0];
    }
    return Row(
      children: feeds.map((f) => Expanded(child: f)).toList(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(AudioRoomState s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1525), _kSurface],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _HeaderIconBtn(
            onTap: () {
              ref.read(audioRoomProvider.notifier).toggleMinimised();
              context.pop();
            },
            icon: Icons.keyboard_arrow_down_rounded,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  s.roomName,
                  style: const TextStyle(
                    color: Color(0xFFEBEBF5),
                    fontSize: 17,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    _HeaderBadge(
                      label: s.groupId != null ? 'Community' : 'Personal',
                      dotColor: const Color(0xFFE84040),
                      labelColor: const Color(0xFFFF7755),
                      bgColor: const Color(0x22DC3C1E),
                      borderColor: const Color(0x55DC501E),
                    ),
                    if (s.cloudRecordingActive) _RecBadge(),
                    if (s.averageRating != null && s.averageRating! > 0)
                      _RatingBadge(rating: s.averageRating!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HeaderIconBtn(
            onTap: _handleShareRoom,
            icon: Icons.ios_share_rounded,
            size: 38,
          ),
        ],
      ),
    );
  }

  // ── Chat divider ───────────────────────────────────────────────────────────
  Widget _buildChatDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF3B82F6).withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_rounded, size: 9, color: Color(0x804E9AFF)),
                SizedBox(width: 5),
                Text(
                  'ADDA CHAT',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    color: Color(0x804E9AFF),
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Emoji strip ────────────────────────────────────────────────────────────
  Widget _buildEmojiStrip() {
    final emojis = ['❤️', '👍', '👎', '👏', '😂', '😭', '😔', '🥺'];

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xE0121930),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 12,
            offset: const Offset(-2, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                _triggerReaction(emoji);
                ref.read(audioRoomProvider.notifier).sendReaction(emoji);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.5),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Seats list ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _buildSeatsList(AudioRoomState s, String? myUid) {
    return List.generate(s.maxSeats, (index) {
      Map<String, dynamic>? occupant;
      for (final sp in s.speakers) {
        final spUid = sp['uid']?.toString().trim();
        if (sp['isEmpty'] != true &&
            spUid != null &&
            spUid.isNotEmpty &&
            spUid != 'null') {
          if (sp['seatIndex'] == index) {
            occupant = sp;
            break;
          }
        }
      }

      if (occupant != null) {
        final uid = occupant['uid']?.toString() ?? '';
        final avatar =
            occupant['profile_pic']?.toString() ?? occupant['avatar']?.toString();
        return {
          'isEmpty': false,
          'uid': uid,
          'name': occupant['name']?.toString() ?? uid,
          'profile_pic': avatar,
          'avatar': avatar,
          'avatar_frame_url':
              (occupant['avatarFrameUrl'] ?? occupant['avatar_frame_url'])
                  ?.toString(),
          'isHost': uid == s.hostUid || occupant['isHost'] == true,
          'isAdmin': occupant['isAdmin'] == true,
          'communityRole': occupant['communityRole']?.toString(),
          'isVerified': occupant['isVerified'] == true,
          'verificationBadge': occupant['verificationBadge'],
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

  // ── Chat bubble ────────────────────────────────────────────────────────────
  Widget _buildChatBubble(Map<String, dynamic> msg) {
    final bool isSystem = msg['isSystem'] == true ||
        msg['senderUid'] == 'system' ||
        msg['type'] == 'system' ||
        msg['senderName'] == 'System';
    final text = msg['text']?.toString() ?? msg['content']?.toString() ?? '';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimaryGlow,
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.campaign_rounded, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x0C2563EB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.15)),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xBBEBEBF5),
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    fontStyle: FontStyle.italic,
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

    final canAskAI = _chatgptFeatureEnabled || _googleAiFeatureEnabled;

    return GestureDetector(
      onLongPress: canAskAI
          ? () {
              setState(() {
                _askAIMessage = msg;
                _showAskAI = true;
              });
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChatAvatar(name: sender, picUrl: senderPic),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        sender,
                        style: TextStyle(
                          color: isMe ? const Color(0xFF60A5FA) : const Color(0xFF93C5FD),
                          fontSize: 11,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Text(time, style: const TextStyle(color: Color(0x38FFFFFF), fontSize: 9, fontFamily: 'Outfit')),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0x182563EB) : const Color(0x0EFFFFFF),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: isMe
                            ? const Color(0xFF2563EB).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.07),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(color: Color(0xE0EBEBF5), fontSize: 13, fontFamily: 'Outfit', height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            offset: Offset(0, -80 * t),
            child: Transform.scale(
              scale: 0.8 + 0.4 * (1 - t),
              child: child,
            ),
          ),
        ),
        child: Text(r.emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }

  // ── Error / ended ──────────────────────────────────────────────────────────
  Widget _buildErrorScreen(AudioRoomState s) {
    final isJoinError = !s.isConnected && s.error != null;
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x22FF9800),
                  border: Border.all(color: const Color(0x55FF9800)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isJoinError ? Icons.wifi_off_rounded : Icons.event_busy_rounded,
                  color: const Color(0xFFFF9800),
                  size: 38,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isJoinError ? 'Could Not Join Adda' : 'This Adda Has Ended',
                style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontFamily: 'Outfit', fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isJoinError
                    ? (s.error ?? 'Unable to join this room. Please try again.')
                    : 'The host has wrapped up this room.\nCheck out other live addas.',
                style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 14, fontFamily: 'Outfit', height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(audioRoomProvider.notifier).leaveRoom();
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Back to Addas',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Participant sheet ──────────────────────────────────────────────────────
  void _showParticipantSheet(Map<String, dynamic> seat) {
    final s = ref.read(audioRoomProvider);
    final myUid = ref.read(authProvider).uid;
    final uid = seat['uid']?.toString() ?? '';
    final isSelf = uid == myUid;
    final isAuthority = s.isHost || s.isAdmin || s.isCoHost;

    final isGhost = seat['isEmpty'] != true &&
        (seat['name'] == null || seat['name'] == 'User' || seat['name'] == uid);
    if (isGhost && !isSelf && isAuthority) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _kCard,
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

    final participantCommunityRole = s.communityRolesMap[uid]?.toString();
    final isParticipantCommunityOwner = participantCommunityRole == 'super_admin';
    final isParticipantCommunityAdmin = participantCommunityRole == 'admin';
    final iAmCommunityOwner = s.myCommunityRole == 'super_admin';
    final iAmCommunityAdmin = s.myCommunityRole == 'admin' || s.myCommunityRole == 'super_admin';
    final isCommunityAdda = s.groupId != null && s.groupId!.isNotEmpty;
    final canDoCommunityActions = isCommunityAdda &&
        iAmCommunityAdmin &&
        !isSelf &&
        !isParticipantCommunityOwner &&
        (!isParticipantCommunityAdmin || iAmCommunityOwner);

    final participantData = {
      'userID': uid,
      'userName': seat['name']?.toString() ?? uid,
      'avatar': seat['profile_pic']?.toString() ?? seat['avatar']?.toString(),
      'avatar_frame_url': (seat['avatarFrameUrl'] ?? seat['avatar_frame_url'])?.toString(),
      'isHost': seat['isHost'] == true,
      'isAdmin': seat['isAdmin'] == true,
      'isMicOn': seat['isMuted'] != true,
      'communityRole': participantCommunityRole,
      'isVerified': seat['isVerified'] == true,
      'verificationBadge': seat['verificationBadge'],
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
      isCommunityAdda: isCommunityAdda,
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
      onCommunityKick: canDoCommunityActions
          ? (p, reason) {
              final name = seat['name']?.toString() ?? uid;
              ref.read(audioRoomProvider.notifier).communityKick(uid, name, reason: reason);
            }
          : null,
      onCommunityBan: canDoCommunityActions
          ? (p, reason) {
              final name = seat['name']?.toString() ?? uid;
              ref.read(audioRoomProvider.notifier).communityBan(uid, name, reason: reason);
            }
          : null,
    );
  }

  // ── ChatGPT / Google AI handlers ───────────────────────────────────────────

  void _handleChatGPTPress() {
    if (!_chatgptFeatureEnabled) {
      _showSnack('ChatGPT AI is currently disabled by admin');
      return;
    }
    setState(() => _showChatGPT = true);
  }

  void _handleGoogleAIPress() {
    if (!_googleAiFeatureEnabled) {
      _showSnack('Google AI is currently disabled by admin');
      return;
    }
    setState(() => _showGoogleAI = true);
  }

  // Called from AskAI sheet — opens Google AI pre-filled with a prompt
  void _handleAskGemini(String prompt) {
    if (!_googleAiFeatureEnabled) {
      _showSnack('Google AI is currently disabled by admin');
      return;
    }
    setState(() {
      _googleAIQuery = prompt;
      _showGoogleAI = true;
    });
  }

  // ── Audio output ───────────────────────────────────────────────────────────
  void _showAudioOutputOptions() {
    final s = ref.read(audioRoomProvider);
    showModalBottomSheet(
      useRootNavigator: true,
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

// ── Remote video view widget ───────────────────────────────────────────────────
/// Wraps VideoTrackRenderer and re-keys on track identity changes to fix
/// Android black-screen bug on screen share.
class _RemoteVideoView extends StatelessWidget {
  final VideoTrack track;
  final bool mirror;

  const _RemoteVideoView({super.key, required this.track, this.mirror = false});

  @override
  Widget build(BuildContext context) {
    return VideoTrackRenderer(
      track,
      mirrorMode: mirror ? VideoViewMirrorMode.mirror : VideoViewMirrorMode.off,
    );
  }
}

// ── Camera control button ─────────────────────────────────────────────────────
class _CamControl extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const _CamControl({required this.icon, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.55),
          border: Border.all(color: (color ?? Colors.white).withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color ?? Colors.white, size: 18),
      ),
    );
  }
}

// ── Reusable header widgets ───────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final double size;

  const _HeaderIconBtn({required this.onTap, required this.icon, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xCCEBEBF5), size: size * 0.52),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final String label;
  final Color dotColor, labelColor, bgColor, borderColor;

  const _HeaderBadge({required this.label, required this.dotColor, required this.labelColor, required this.bgColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(7), border: Border.all(color: borderColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: labelColor, fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

class _RecBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: const Color(0x22EF4444), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x55EF4444))),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlinkingRecDot(),
          SizedBox(width: 4),
          Text('REC', style: TextStyle(color: Color(0xFFEF4444), fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: const Color(0x22FFA726), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x55FFA726))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 9, color: Color(0xFFFFA726)),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1), style: const TextStyle(color: Color(0xFFFFA726), fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Chat avatar ────────────────────────────────────────────────────────────────
class _ChatAvatar extends StatelessWidget {
  final String name;
  final String? picUrl;
  const _ChatAvatar({required this.name, this.picUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D4A7A), Color(0xFF1A3050)],
        ),
        border: Border.all(color: const Color(0x33FFFFFF), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: picUrl != null && picUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: picUrl!,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _letter(initial),
                placeholder: (_, __) => _letter(initial),
              ),
            )
          : _letter(initial),
    );
  }

  Widget _letter(String initial) {
    return Center(
      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
    );
  }
}

// ── Blinking REC dot ───────────────────────────────────────────────────────────
class _BlinkingRecDot extends StatefulWidget {
  const _BlinkingRecDot();

  @override
  State<_BlinkingRecDot> createState() => _BlinkingRecDotState();
}

class _BlinkingRecDotState extends State<_BlinkingRecDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEF4444))),
    );
  }
}

// ── Floating reaction ──────────────────────────────────────────────────────────
class _FloatingReaction {
  final String id, emoji;
  final double x, y;
  const _FloatingReaction({required this.id, required this.emoji, required this.x, required this.y});
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheets
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  final String title, message, confirmText;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmSheet({required this.title, required this.message, required this.confirmText, required this.confirmColor, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF111828), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 14, fontFamily: 'Outfit'), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x30FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xAAFFFFFF), fontFamily: 'Outfit')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); onConfirm(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

class _SeatRequestsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> queue;
  final void Function(String uid) onAccept;
  final void Function(String uid) onReject;

  const _SeatRequestsSheet({required this.queue, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF111828), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: _SheetHandle()),
          const SizedBox(height: 14),
          const Text('Seat Requests', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (queue.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No pending requests', style: TextStyle(color: Color(0x60FFFFFF), fontFamily: 'Outfit')),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: queue.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0x10FFFFFF), height: 1),
                itemBuilder: (_, i) {
                  final req = queue[i];
                  final uid = req['uid']?.toString() ?? '';
                  final name = req['name']?.toString() ?? uid;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0x142563EB),
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF34C759), size: 28),
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
      decoration: const BoxDecoration(color: Color(0xFF111828), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: _SheetHandle()),
          const SizedBox(height: 14),
          Text('Audience (${audience.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (audience.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No audience members yet', style: TextStyle(color: Color(0x60FFFFFF), fontFamily: 'Outfit')),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: audience.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0x10FFFFFF), height: 1),
                itemBuilder: (_, i) {
                  final m = audience[i];
                  final name = m['name']?.toString() ?? m['uid']?.toString() ?? 'User';
                  final pic = m['profile_pic']?.toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF2D4A7A), Color(0xFF1A3050)])),
                      clipBehavior: Clip.antiAlias,
                      child: (pic != null && pic.isNotEmpty)
                          ? ClipOval(child: CachedNetworkImage(imageUrl: pic, width: 36, height: 36, fit: BoxFit.cover, errorWidget: (_, __, ___) => _letterWidget(name), placeholder: (_, __) => _letterWidget(name)))
                          : _letterWidget(name),
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

  Widget _letterWidget(String name) {
    return Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)));
  }
}

class _AudioOutputSheet extends StatelessWidget {
  final String currentMode;
  final bool bluetoothAvailable;
  final void Function(String mode) onSelect;

  const _AudioOutputSheet({required this.currentMode, required this.onSelect, this.bluetoothAvailable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF111828), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: _SheetHandle()),
          const SizedBox(height: 14),
          const Text('Audio Output', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _audioOption(context, 'speaker', Icons.volume_up_rounded, 'Loudspeaker'),
          _audioOption(context, 'earpiece', Icons.hearing_rounded, 'Earpiece'),
          if (bluetoothAvailable) _audioOption(context, 'bluetooth', Icons.bluetooth_audio_rounded, 'Bluetooth'),
        ],
      ),
    );
  }

  Widget _audioOption(BuildContext context, String mode, IconData icon, String label) {
    final isSelected = currentMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.white60),
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF2563EB) : Colors.white, fontFamily: 'Outfit')),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB)) : null,
      onTap: () { Navigator.pop(context); onSelect(mode); },
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(100)),
    );
  }
}
