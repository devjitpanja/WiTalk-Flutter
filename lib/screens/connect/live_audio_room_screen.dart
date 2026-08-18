import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart' hide PlayerState;
import 'package:shared_preferences/shared_preferences.dart';
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
import '../../widgets/audio_room/recording_info_bottom_sheet.dart';
import '../../cache/witalk_image_cache.dart';
import '../../analytics/analytics_service.dart';
import '../../services/adda_session_tracking_service.dart';
import '../../utils/mic_permission_utils.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kBg = Color(0xFF0D1017);
const Color _kSurface = Color(0xFF0D1017);
const Color _kCard = Color(0xFF111828);
const Color _kPrimary = Color(0xFF0751DF);
const Color _kPrimaryGlow = Color(0x330751DF);

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

  final List<_ReactionData> _reactionOverlays = [];
  late AnimationController _pulseCtrl;
  bool _isRoomEnded = false;
  bool _reactionCooldown = false;

  final _sessionTracking = AddaSessionTrackingService();
  bool _sessionStarted = false;

  // ── ChatGPT / Google AI state (mirrors RN) ──────────────────────────────────
  bool _showChatGPT = false;
  bool _showGoogleAI = false;
  String? _googleAIQuery;   // pre-filled query from "Ask AI" chat context menu
  bool _showAskAI = false;
  Map<String, dynamic>? _askAIMessage; // selected chat message for AskAI sheet

  // Admin feature flags (loaded from settings in RN; default true in Flutter)
  bool _chatgptFeatureEnabled = true;
  bool _googleAiFeatureEnabled = true;

  // Recording announcement guards
  bool _roomLoaded = false;
  bool _hasPlayedRecAnnouncement = false;

  // ── Leave / close state ─────────────────────────────────────────────────────
  bool _showBackPressDialog = false;
  bool _showLeaveDialog = false;
  bool _showCloseAddaSheet = false;
  bool _closeAddaLoading = false;
  Map<String, dynamic> _leaveDialogConfig = {};

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!widget.restore) {
        final granted = await checkMicPermission(context);
        if (!granted) {
          if (context.mounted) context.pop();
          return;
        }
      }
      if (!mounted) return;
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
    _sessionTracking.dispose();
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

  // ── Recording announcement ──────────────────────────────────────────────────

  Future<void> _maybePlayRecAnnouncement(AudioRoomState s) async {
    if (!_roomLoaded || !s.cloudRecordingActive || _hasPlayedRecAnnouncement) return;
    if (!mounted) return;
    _hasPlayedRecAnnouncement = true;

    const key = 'rec_announcement_last_played';
    const fiveHoursMs = 5 * 3600 * 1000;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(key) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < fiveHoursMs) return;
      await prefs.setInt(key, now);
    } catch (_) {
      // Storage failure — proceed with announcement anyway
    }

    if (!mounted) return;
    if (s.isHost) _showSnack('This adda is being recorded');
    if (Platform.isAndroid) {
      try {
        final player = AudioPlayer();
        await player.play(AssetSource('audio/adda.mp3'));
        player.onPlayerComplete.first.then((_) => player.dispose());
      } catch (_) {}
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
        notifier.toggleHandRaise(seatIndex: seatIndex);
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
    _sessionTracking.onSeatTaken(seatIndex);
    final s2 = ref.read(audioRoomProvider);
    AnalyticsService.logAddaSeatTaken(
      addaId: widget.roomId,
      seatIndex: seatIndex,
      addaTopic: s2.roomName,
    );
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
    final s = ref.read(audioRoomProvider);
    final notifier = ref.read(audioRoomProvider.notifier);

    // Frozen room — host cannot close
    if (s.isHost && s.closeFrozen) {
      setState(() {
        _leaveDialogConfig = {
          'title': 'Adda Pinned Open',
          'message': 'This Adda has been pinned open by the Platform Moderator — you cannot close it right now.',
          'confirmText': 'OK',
          'cancelText': null,
          'onConfirm': () => setState(() => _showLeaveDialog = false),
        };
        _showLeaveDialog = true;
      });
      return;
    }

    if (s.isHost) {
      // Host: show CloseAdda bottom sheet
      setState(() => _showCloseAddaSheet = true);
    } else if (s.isAdmin) {
      _handleAdminLeave(s, notifier);
    } else if (s.isInSeat) {
      _handleInSeatLeave(s, notifier);
    } else {
      _handleAudienceLeave(s, notifier);
    }
  }

  void _handleAdminLeave(AudioRoomState s, dynamic notifier) {
    final myUid = ref.read(authProvider).uid ?? '';
    final hostPresent = s.speakers.any((sp) => sp['isHost'] == true && sp['isEmpty'] != true);

    Future<void> doAdminLeave(VoidCallback afterLeave) async {
      await _sessionTracking.onLeave();
      try {
        if (s.isInSeat) {
          notifier.leaveSeat();
          await Future.delayed(const Duration(milliseconds: 150));
        }
        await notifier.leaveRoom();
        if (mounted) setState(() => _showLeaveDialog = false);
        afterLeave();
      } catch (_) {
        if (mounted) setState(() => _showLeaveDialog = false);
        afterLeave();
      }
    }

    if (hostPresent) {
      setState(() {
        _leaveDialogConfig = {
          'title': 'Leave Adda',
          'message': 'Are you sure you want to leave this Adda?',
          'confirmText': 'Leave',
          'cancelText': 'Cancel',
          'onConfirm': () => doAdminLeave(() { if (mounted) context.pop(); }),
          'onCancel': () => setState(() => _showLeaveDialog = false),
        };
        _showLeaveDialog = true;
      });
    } else {
      final anotherAdminPresent = s.admins.any((uid) => uid != myUid);
      if (anotherAdminPresent) {
        setState(() {
          _leaveDialogConfig = {
            'title': 'Leave Adda',
            'message': 'The host is not present. You can leave — another admin will keep the room running.',
            'confirmText': 'Leave',
            'cancelText': 'Close Adda',
            'onConfirm': () => doAdminLeave(() { if (mounted) context.pop(); }),
            'onCancel': () async {
              setState(() => _leaveDialogConfig = {..._leaveDialogConfig, 'loading': true});
              await _executeCloseRoom(isAdminClose: true);
              if (mounted) {
                setState(() => _showLeaveDialog = false);
                context.pop();
              }
            },
          };
          _showLeaveDialog = true;
        });
      } else {
        setState(() {
          _leaveDialogConfig = {
            'title': 'Close Adda',
            'message': 'You are the only admin and the host is not present. You must close the Adda for everyone before leaving.',
            'confirmText': 'Close Adda',
            'cancelText': 'Cancel',
            'onConfirm': () async {
              setState(() => _leaveDialogConfig = {..._leaveDialogConfig, 'loading': true});
              await _executeCloseRoom(isAdminClose: true);
              if (mounted) {
                setState(() => _showLeaveDialog = false);
                context.pop();
              }
            },
            'onCancel': () => setState(() => _showLeaveDialog = false),
          };
          _showLeaveDialog = true;
        });
      }
    }
  }

  void _handleInSeatLeave(AudioRoomState s, dynamic notifier) {
    Future<void> doLeave(VoidCallback afterLeave) async {
      await _sessionTracking.onLeave();
      try {
        if (s.isInSeat) {
          notifier.leaveSeat();
          await Future.delayed(const Duration(milliseconds: 150));
        }
        await notifier.leaveRoom();
        if (mounted) setState(() => _showLeaveDialog = false);
        afterLeave();
      } catch (_) {
        if (mounted) setState(() => _showLeaveDialog = false);
        afterLeave();
      }
    }

    setState(() {
      _leaveDialogConfig = {
        'title': 'Leave Adda',
        'message': 'Are you sure you want to leave this Adda?',
        'confirmText': 'Leave',
        'cancelText': 'Cancel',
        'onConfirm': () => doLeave(() { if (mounted) context.pop(); }),
        'onCancel': () => setState(() => _showLeaveDialog = false),
      };
      _showLeaveDialog = true;
    });
  }

  void _handleAudienceLeave(AudioRoomState s, dynamic notifier) {
    Future<void> doLeave(VoidCallback afterLeave) async {
      await _sessionTracking.onLeave();
      try {
        await notifier.leaveRoom();
        if (mounted) setState(() => _showLeaveDialog = false);
        afterLeave();
      } catch (_) {
        if (mounted) setState(() => _showLeaveDialog = false);
        afterLeave();
      }
    }

    setState(() {
      _leaveDialogConfig = {
        'title': 'Leave Adda',
        'message': 'Are you sure you want to leave this Adda?',
        'confirmText': 'Leave',
        'cancelText': 'Cancel',
        'onConfirm': () => doLeave(() { if (mounted) context.pop(); }),
        'onCancel': () => setState(() => _showLeaveDialog = false),
      };
      _showLeaveDialog = true;
    });
  }

  Future<void> _executeCloseRoom({bool isAdminClose = false}) async {
    final notifier = ref.read(audioRoomProvider.notifier);
    try {
      await _sessionTracking.onLeave();
      await notifier.endRoom();
    } catch (_) {
      await notifier.leaveRoom();
    }
  }

  Future<void> _handleDoCloseAdda() async {
    setState(() => _closeAddaLoading = true);
    try {
      await _executeCloseRoom(isAdminClose: false);
      if (mounted) {
        setState(() {
          _showCloseAddaSheet = false;
          _closeAddaLoading = false;
        });
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _showCloseAddaSheet = false;
          _closeAddaLoading = false;
        });
        context.pop();
      }
    }
  }

  Future<void> _handleHandoverToAdmin() async {
    setState(() => _closeAddaLoading = true);
    final notifier = ref.read(audioRoomProvider.notifier);
    final s = ref.read(audioRoomProvider);
    try {
      if (s.isInSeat) {
        notifier.leaveSeat();
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await notifier.leaveRoom();
      if (mounted) {
        setState(() {
          _showCloseAddaSheet = false;
          _closeAddaLoading = false;
        });
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _closeAddaLoading = false);
        _showSnack('Failed to hand over. Please try again.');
      }
    }
  }

  void _handleLeaveNoAdmin() {
    setState(() {
      _leaveDialogConfig = {
        'title': 'No Admin Available',
        'message': 'You need to assign at least one participant as an admin before you can leave the Adda. Go to a participant\'s profile and tap "Make Admin".',
        'confirmText': 'OK',
        'cancelText': null,
        'onConfirm': () => setState(() => _showLeaveDialog = false),
      };
      _showLeaveDialog = true;
    });
  }

  List<Map<String, dynamic>> _getEligibleHandoverAdmins(AudioRoomState s) {
    if (!s.isHost) return [];
    return s.admins.where((uid) {
      return s.speakers.any((sp) =>
        sp['uid']?.toString() == uid && sp['isEmpty'] != true,
      );
    }).map((uid) {
      final prof = s.participantProfiles[uid];
      return {
        'uid': uid,
        'name': prof?['name'] ?? prof?['username'] ?? uid,
        'profile_pic': prof?['profile_pic'] ?? prof?['profilePic'],
      };
    }).toList();
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

  int _getSeatIndexForUser(String uid, AudioRoomState state) {
    for (final sp in state.speakers) {
      if (sp['uid']?.toString() == uid && sp['isEmpty'] != true) {
        final si = sp['seatIndex'];
        return si is int ? si : int.tryParse(si?.toString() ?? '') ?? -1;
      }
    }
    return -1;
  }

  Offset? _computeSeatPosition(int seatIndex, {bool compact = false, int maxSeats = 8}) {
    if (seatIndex < 0) return null;
    final screenWidth = MediaQuery.of(context).size.width;
    const edgePadding = 8.0;
    // Match GridSeatingLayout: compact+12 seats → 6 columns, otherwise 4
    final int seatsPerRow = (compact && maxSeats == 12) ? 6 : 4;
    final seatWidth = (screenWidth - edgePadding * 2) / seatsPerRow;
    final double avatarSize;
    final double seatHeight;
    if (compact) {
      avatarSize = (seatWidth * 0.42).clamp(28.0, 44.0);
      seatHeight = avatarSize * 1.3;
    } else {
      avatarSize = (seatWidth * 0.60).clamp(40.0, 62.0);
      final nameFontSize = (avatarSize * 0.20).clamp(9.0, 11.0);
      seatHeight = avatarSize * 1.5 + 1 + nameFontSize + 6;
    }
    // runSpacing matches GridSeatingLayout: 0 in compact, 2 otherwise
    final double runSpacing = compact ? 0.0 : 2.0;
    // Non-compact has a "BAITHAK" header row above the Wrap (~29px: 8 top + 17 badge + 4 bottom)
    const double headerHeight = 29.0;
    const double wrapTopPad = 2.0;
    final double gridVertPad = compact ? wrapTopPad : wrapTopPad + headerHeight;

    final col = seatIndex % seatsPerRow;
    final row = seatIndex ~/ seatsPerRow;
    final cx = edgePadding + col * seatWidth + seatWidth / 2;
    // Avatar is Center-ed within seatHeight → avatar center ≈ seatHeight / 2 from seat top
    final cy = gridVertPad + row * (seatHeight + runSpacing) + seatHeight / 2;
    return Offset(cx, cy);
  }

  void _addReactionForSeat(String emoji, int seatIndex, {bool compact = false, int maxSeats = 8}) {
    final pos = _computeSeatPosition(seatIndex, compact: compact, maxSeats: maxSeats);
    if (pos == null) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    if (mounted) {
      setState(() {
        _reactionOverlays.add(_ReactionData(id: id, emoji: emoji, cx: pos.dx, cy: pos.dy));
      });
    }
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

      // ── Recording announcement ─────────────────────────────────────────────
      // Mark room as loaded when seats are first initialized (room fully joined)
      if (!_roomLoaded && next.seatsInitialized) {
        _roomLoaded = true;
        _maybePlayRecAnnouncement(next);
      }
      // Play announcement when recording starts after room is already loaded
      if (next.cloudRecordingActive && !(prev?.cloudRecordingActive ?? false)) {
        _maybePlayRecAnnouncement(next);
      }

      // ── Remote reactions pinned to avatars ────────────────────────────────
      if (next.activeReactions.length > (prev?.activeReactions.length ?? 0)) {
        final prevIds = prev?.activeReactions.map((r) => r['id']).toSet() ?? {};
        for (final r in next.activeReactions) {
          if (!prevIds.contains(r['id'])) {
            final uid = r['uid']?.toString() ?? '';
            final seatIdx = _getSeatIndexForUser(uid, next);
            if (seatIdx >= 0) {
              final isCompact = next.youtubeVideoId != null || false;
              final seats = next.maxSeats;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _addReactionForSeat(r['emoji']?.toString() ?? '❤️', seatIdx, compact: isCompact, maxSeats: seats);
              });
            }
          }
        }
      }

      // ── Analytics session tracking ─────────────────────────────────────────
      // Start session when room first becomes connected
      if (next.isConnected && !(prev?.isConnected ?? false) && !_sessionStarted) {
        _sessionStarted = true;
        final participantCount = next.audience.length +
            next.speakers.where((s) => s['userId'] != null).length;
        _sessionTracking.startSession(
          roomId: widget.roomId,
          roomName: next.roomName,
          userRole: next.isHost ? 'host' : 'audience',
          isHost: next.isHost,
          participantCount: participantCount,
          isMuted: next.isMuted,
        );
      }

      // Track mute/unmute changes for Adda_Speaker_Unmuted + session
      if (prev != null && next.isMuted != prev.isMuted) {
        if (!next.isMuted) {
          // User just unmuted (went live on stage)
          _sessionTracking.onUnmuted();
          if (next.isInSeat) {
            AnalyticsService.logAddaSpeakerUnmuted(
              addaId: widget.roomId,
              seatIndex: next.currentSeatIndex >= 0 ? next.currentSeatIndex : null,
            );
          }
        } else {
          _sessionTracking.onMuted();
        }
      }

      // Track seat left
      if (prev != null && prev.isInSeat && !next.isInSeat) {
        _sessionTracking.onLeftSeat();
      }

      // Track participant count changes
      if (prev != null) {
        final newCount = next.audience.length +
            next.speakers.where((s) => s['userId'] != null).length;
        final oldCount = prev.audience.length +
            prev.speakers.where((s) => s['userId'] != null).length;
        if (newCount != oldCount) {
          _sessionTracking.onParticipantCountChanged(newCount);
        }

        // Track speaker count changes (for host quality events)
        final newSpeakers =
            next.speakers.where((s) => s['userId'] != null && s['isMuted'] != true).length;
        final oldSpeakers =
            prev.speakers.where((s) => s['userId'] != null && s['isMuted'] != true).length;
        if (newSpeakers != oldSpeakers) {
          _sessionTracking.onSpeakerCountChanged(newSpeakers);
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

    final eligibleAdmins = _getEligibleHandoverAdmins(roomState);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (roomState.isLoading || _isRoomEnded || roomState.error != null) return;
        if (_showLeaveDialog || _showBackPressDialog) return;
        setState(() => _showBackPressDialog = true);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
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
                      onLockedSeatTap: _handleEmptySeatPress,
                      onEmptySeatLongPress: (idx) {
                        if (roomState.isHost) {
                          ref.read(audioRoomProvider.notifier).toggleSeatLock(idx);
                        }
                      },
                      onShowAudienceList: _showAudienceList,
                      onAudienceMemberTap: (m) => _showParticipantSheet(m),
                    ),
                    // ── Reaction overlays pinned to avatars ──────
                    ..._reactionOverlays.map((r) => Positioned(
                      left: r.cx - 18,
                      top: r.cy - 18,
                      width: 36,
                      height: 36,
                      child: IgnorePointer(
                        child: _ReactionOverlay(
                          key: ValueKey(r.id),
                          emoji: r.emoji,
                          onDone: () {
                            if (mounted) setState(() => _reactionOverlays.removeWhere((x) => x.id == r.id));
                          },
                        ),
                      ),
                    )),
                  ],
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

                    if (roomState.isInSeat || roomState.isHost)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _buildEmojiStrip(),
                      ),
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

        // ── Back press dialog (Minimize or Leave) ─────────────────────
        if (_showBackPressDialog)
          _LeaveAlertDialog(
            title: 'Adda is Active',
            message: 'Would you like to minimize this Adda or leave?',
            confirmText: roomState.isHost ? 'Close Adda' : 'Leave Adda',
            confirmColor: const Color(0xFFEF4444),
            cancelText: 'Cancel',
            thirdActionText: 'Minimize',
            thirdActionColor: const Color(0xFF3B82F6),
            onConfirm: () {
              setState(() => _showBackPressDialog = false);
              _handleLeave();
            },
            onThirdAction: () {
              setState(() => _showBackPressDialog = false);
              ref.read(audioRoomProvider.notifier).minimizeRoom();
              context.pop();
            },
            onCancel: () => setState(() => _showBackPressDialog = false),
          ),

        // ── Leave dialog (admin / audience scenarios) ─────────────────
        if (_showLeaveDialog)
          _LeaveAlertDialog(
            title: (_leaveDialogConfig['title'] as String?) ?? 'Leave Adda',
            message: (_leaveDialogConfig['message'] as String?) ?? '',
            confirmText: (_leaveDialogConfig['confirmText'] as String?) ?? 'Leave',
            confirmColor: roomState.isHost ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            cancelText: (_leaveDialogConfig['cancelText'] as String?) ?? 'Cancel',
            showCancel: true,
            loading: (_leaveDialogConfig['loading'] as bool?) ?? false,
            onConfirm: () => (_leaveDialogConfig['onConfirm'] as VoidCallback?)?.call(),
            onCancel: () {
              final onCancel = _leaveDialogConfig['onCancel'] as VoidCallback?;
              if (onCancel != null) {
                onCancel();
              } else {
                setState(() => _showLeaveDialog = false);
              }
            },
          ),

        // ── Close Adda sheet (host only) ──────────────────────────────
        if (roomState.isHost)
          _CloseAddaBottomSheet(
            visible: _showCloseAddaSheet,
            loading: _closeAddaLoading,
            hasEligibleAdmins: eligibleAdmins.isNotEmpty,
            onClose: () { if (!_closeAddaLoading) setState(() => _showCloseAddaSheet = false); },
            onLeaveAdda: eligibleAdmins.isNotEmpty ? _handleHandoverToAdmin : _handleLeaveNoAdmin,
            onCloseAdda: _handleDoCloseAdda,
          ),
      ],
        ),
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
            const Icon(Icons.screen_share, color: Color(0xFF0751DF), size: 20),
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
                    const Icon(Icons.screen_share, color: Color(0xFF0751DF), size: 32),
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
                onLockedSeatTap: _handleEmptySeatPress,
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
        color: const Color(0xFF0D1118),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF0751DF).withValues(alpha: 0.12),
            width: 1,
          ),
        ),
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
                    if (s.cloudRecordingActive)
                      GestureDetector(
                        onTap: () => RecordingInfoBottomSheet.show(context),
                        child: _RecBadge(),
                      ),
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
            icon: Icons.share_rounded,
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
                    const Color(0xFF0751DF).withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0751DF).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF0751DF).withValues(alpha: 0.18),
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
                    const Color(0xFF0751DF).withValues(alpha: 0.25),
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
                if (_reactionCooldown) {
                  _showSnack('Wait 10 seconds before sending another reaction.');
                  return;
                }
                final s = ref.read(audioRoomProvider);
                final myUid = ref.read(authProvider).uid ?? '';
                final seatIdx = _getSeatIndexForUser(myUid, s);
                final isCompact = s.youtubeVideoId != null || false;
                _addReactionForSeat(emoji, seatIdx, compact: isCompact, maxSeats: s.maxSeats);
                ref.read(audioRoomProvider.notifier).sendReaction(emoji);
                setState(() => _reactionCooldown = true);
                Future.delayed(const Duration(seconds: 10), () {
                  if (mounted) setState(() => _reactionCooldown = false);
                });
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
                border: Border.all(color: const Color(0xFF0751DF).withValues(alpha: 0.35)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.campaign_rounded, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x0C0751DF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0751DF).withValues(alpha: 0.15)),
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
            GestureDetector(
              onTap: () {
                final senderUid = (msg['senderUid'] ?? msg['sender_uid'] ?? '')
                    .toString();
                if (senderUid.isEmpty || senderUid == 'system') return;
                _showParticipantSheet({
                  'uid': senderUid,
                  'name': sender,
                  'profile_pic': senderPic,
                  'avatar': senderPic,
                  'isHost': msg['isHost'] == true,
                  'isAdmin': msg['isAdmin'] == true,
                  'isMuted': false,
                  'isEmpty': false,
                  'isVerified': msg['isVerified'] == true,
                  'verificationBadge': msg['verificationBadge'],
                });
              },
              child: _ChatAvatar(name: sender, picUrl: senderPic),
            ),
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
                      color: isMe ? const Color(0x180751DF) : const Color(0x0EFFFFFF),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: isMe
                            ? const Color(0xFF0751DF).withValues(alpha: 0.22)
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
          color: const Color(0xFF0751DF).withValues(alpha: 0.08),
          border: Border.all(color: const Color(0xFF0751DF).withValues(alpha: 0.20), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFF0751DF), size: size * 0.52),
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
        cacheManager: WiTalkImageCache(),
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

// ── Reaction data + overlay ────────────────────────────────────────────────────

class _ReactionData {
  final String id, emoji;
  final double cx, cy;
  const _ReactionData({required this.id, required this.emoji, required this.cx, required this.cy});
}

class _ReactionOverlay extends StatefulWidget {
  final String emoji;
  final VoidCallback onDone;
  const _ReactionOverlay({super.key, required this.emoji, required this.onDone});

  @override
  State<_ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<_ReactionOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    // Total: 300ms appear + 2200ms hold + 500ms fade = 3000ms
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 5),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 68),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeIn)), weight: 17),
    ]).animate(_ctrl);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 83),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 17),
    ]).animate(_ctrl);

    // Shake: 5 × 80ms = 400ms / 3000ms ≈ 13.3% of duration
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0), weight: 5),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 87),
    ]).animate(_ctrl);

    _ctrl.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(_shake.value, 0),
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        ),
      ),
      child: Center(
        child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
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
                      backgroundColor: const Color(0x140751DF),
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
                          ? ClipOval(child: CachedNetworkImage(
        cacheManager: WiTalkImageCache(),imageUrl: pic, width: 36, height: 36, fit: BoxFit.cover, errorWidget: (_, __, ___) => _letterWidget(name), placeholder: (_, __) => _letterWidget(name)))
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
      leading: Icon(icon, color: isSelected ? const Color(0xFF0751DF) : Colors.white60),
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF0751DF) : Colors.white, fontFamily: 'Outfit')),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF0751DF)) : null,
      onTap: () { onSelect(mode); Navigator.pop(context); },
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

// ── Leave Alert Dialog ─────────────────────────────────────────────────────
class _LeaveAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final Color confirmColor;
  final String cancelText;
  final bool showCancel;
  final bool loading;
  final String? thirdActionText;
  final Color? thirdActionColor;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onThirdAction;

  const _LeaveAlertDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.confirmColor,
    this.cancelText = 'Cancel',
    this.showCancel = true,
    this.loading = false,
    this.thirdActionText,
    this.thirdActionColor,
    required this.onConfirm,
    required this.onCancel,
    this.onThirdAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: !loading ? onCancel : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // absorb taps
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xCC1C1C1E),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 8))],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFFEBEBF5), fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(message, style: const TextStyle(color: Color(0xAAEBEBF5), fontSize: 14, fontFamily: 'Outfit', height: 1.5)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Cancel — far left
                      if (showCancel)
                        TextButton(
                          onPressed: !loading ? onCancel : null,
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          child: Text(cancelText, style: TextStyle(color: const Color(0xFF3B82F6).withValues(alpha: loading ? 0.5 : 1.0), fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      const Spacer(),
                      // Third action (optional)
                      if (thirdActionText != null && onThirdAction != null)
                        TextButton(
                          onPressed: !loading ? onThirdAction : null,
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          child: Text(thirdActionText!, style: TextStyle(color: thirdActionColor ?? const Color(0xFF7B61FF), fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      // Confirm — far right
                      TextButton(
                        onPressed: !loading ? onConfirm : null,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        child: loading
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: confirmColor, strokeWidth: 2))
                            : Text(confirmText, style: TextStyle(color: confirmColor, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Close Adda Bottom Sheet (host only) ────────────────────────────────────
class _CloseAddaBottomSheet extends StatelessWidget {
  final bool visible;
  final bool loading;
  final bool hasEligibleAdmins;
  final VoidCallback onClose;
  final VoidCallback onLeaveAdda;
  final VoidCallback onCloseAdda;

  const _CloseAddaBottomSheet({
    required this.visible,
    required this.loading,
    required this.hasEligibleAdmins,
    required this.onClose,
    required this.onLeaveAdda,
    required this.onCloseAdda,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: !loading ? onClose : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // absorb taps
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1a1d2e),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: const Color(0xFF0751DF).withValues(alpha: 0.25)),
                  left: BorderSide(color: const Color(0xFF0751DF).withValues(alpha: 0.25)),
                  right: BorderSide(color: const Color(0xFF0751DF).withValues(alpha: 0.25)),
                ),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, math.max(bottomPad, 20.0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  const Text('Leave Adda', style: TextStyle(color: Color(0xFFEBEBF5), fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text('Choose what happens when you leave', style: TextStyle(color: const Color(0xFFC8D2FF).withValues(alpha: 0.6), fontSize: 13, fontFamily: 'Outfit')),
                  const SizedBox(height: 18),
                  Divider(color: const Color(0xFF0751DF).withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 16),

                  if (loading) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFF0751DF), strokeWidth: 2),
                          const SizedBox(width: 12),
                          Text('Please wait…', style: TextStyle(color: const Color(0xFFC8D2FF).withValues(alpha: 0.7), fontSize: 14, fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Leave Adda button
                    _CloseSheetOption(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFF0751DF),
                      iconBgColor: const Color(0xFF0751DF).withValues(alpha: 0.12),
                      iconBorderColor: const Color(0xFF0751DF).withValues(alpha: 0.25),
                      bgColor: const Color(0xFF0751DF).withValues(alpha: 0.07),
                      borderColor: const Color(0xFF0751DF).withValues(alpha: 0.2),
                      title: 'Leave Adda',
                      titleColor: const Color(0xFF7aa3f5),
                      subtitle: hasEligibleAdmins ? 'Admins will keep the room running' : 'Make someone an admin first',
                      subtitleColor: const Color(0xFF7aa3f5).withValues(alpha: 0.6),
                      chevronColor: const Color(0xFF0751DF).withValues(alpha: 0.5),
                      onTap: onLeaveAdda,
                    ),
                    Divider(color: const Color(0xFF0751DF).withValues(alpha: 0.15), height: 28),
                    // End Adda for Everyone button
                    _CloseSheetOption(
                      icon: Icons.cancel_rounded,
                      iconColor: const Color(0xFFff4444),
                      iconBgColor: const Color(0xFFff4444).withValues(alpha: 0.12),
                      iconBorderColor: const Color(0xFFff4444).withValues(alpha: 0.25),
                      bgColor: const Color(0xFFff4444).withValues(alpha: 0.07),
                      borderColor: const Color(0xFFff4444).withValues(alpha: 0.2),
                      title: 'End Adda for Everyone',
                      titleColor: const Color(0xFFff6b6b),
                      subtitle: 'All participants will be removed',
                      subtitleColor: const Color(0xFFff6b6b).withValues(alpha: 0.6),
                      chevronColor: const Color(0xFFff4444).withValues(alpha: 0.5),
                      onTap: onCloseAdda,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseSheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color iconBorderColor;
  final Color bgColor;
  final Color borderColor;
  final String title;
  final Color titleColor;
  final String subtitle;
  final Color subtitleColor;
  final Color chevronColor;
  final VoidCallback onTap;

  const _CloseSheetOption({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconBorderColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.subtitleColor,
    required this.chevronColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle, border: Border.all(color: iconBorderColor)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: titleColor, fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Outfit')),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }
}
