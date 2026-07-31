import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_room_service.dart';
import '../../services/chat_api_service.dart';
import '../../theme/theme_colors.dart';
import '../../utils/image_utils.dart';
import '../../utils/input_shield.dart';
import '../../utils/time_utils.dart';
import '../../widgets/common/custom_alert_dialog.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const int _kMaxScheduled = 5;
const int _kMinScheduleMinutes = 15;

const List<Map<String, String>> _kReportReasons = [
  {'key': 'spam', 'label': 'Spam or advertisement'},
  {'key': 'offensive', 'label': 'Offensive or hateful language'},
  {'key': 'misleading', 'label': 'Misleading or false information'},
  {'key': 'other', 'label': 'Other'},
];

const List<String> _kUsernameAdjectives = [
  'brave', 'calm', 'cool', 'deft', 'epic', 'fast', 'bold', 'keen',
  'loud', 'mild', 'neat', 'pure', 'rare', 'real', 'safe', 'wise',
  'warm', 'wild', 'keen', 'true', 'free', 'deep', 'dawn', 'best',
  'kind', 'lush', 'open', 'peak', 'rich', 'soft', 'tidy', 'vibe',
];

const List<String> _kUsernameNouns = [
  'adda', 'beam', 'chat', 'club', 'dune', 'echo', 'flare', 'flow',
  'glow', 'hive', 'isle', 'jade', 'kite', 'lark', 'mesa', 'nova',
  'opal', 'pine', 'quay', 'rift', 'sage', 'tide', 'umph', 'vale',
  'wave', 'xray', 'yard', 'zeal', 'arc', 'bay', 'cove', 'den',
  'elm', 'fen', 'glen', 'hub', 'inn', 'jet', 'key', 'lea',
  'moor', 'net', 'orb', 'pod',
];

const Map<String, List<String>> _kRulesPresets = {
  'New to the City': [
    'Be welcoming and friendly to newcomers',
    'Share helpful tips about the city',
    'No spam or self-promotion',
    'Speak respectfully',
  ],
  'Make True Friends': [
    'Be genuine and kind',
    'No judgment — everyone is welcome',
    'Keep personal info private',
    'No spam or promotional links',
  ],
  'English Speaking': [
    'Speak only in English',
    'Be patient with learners',
    'Correct mistakes kindly',
    'No off-topic conversations',
  ],
  'Late Night': [
    'Keep it chill and relaxed',
    'No controversial or heated topics',
    'Be respectful of everyone',
  ],
  'Startup / Career': [
    'Stay on topic — startups & career only',
    'Share genuine insights, not promotions',
    'Be respectful of different experience levels',
  ],
  'Stranger Stories': [
    'Keep stories real and personal',
    'No names or identifiable info about others',
    'One speaker at a time',
  ],
};

const List<String> _kUniversalRules = [
  'Be respectful to all participants',
  'No hate speech or discrimination',
  'No spam or self-promotion',
  "Follow the host's instructions",
];

String _generateRulesForTopic(String topicName) {
  final rules = _kRulesPresets[topicName] ?? _kUniversalRules;
  return rules.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
}

bool _isProfane(String text) {
  final cleaned = text.replaceAll(RegExp(r'[^a-zA-Z0-9ऀ-ॿ ]'), '').replaceAllMapped(
    RegExp(r'(.)\1+', caseSensitive: false),
    (m) => m.group(1)!,
  );
  final result = validateInput(cleaned, minLength: 1, maxLength: 200);
  return result.reason == 'profanity';
}

bool _isValidChannelNameFormat(String? s) =>
    s != null && s.isNotEmpty && RegExp(r'^[a-zA-Z_-]+$').hasMatch(s);

String _formatScheduledTime(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);

  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final ampm = date.hour >= 12 ? 'PM' : 'AM';
  final timeStr = '$hour:$minute $ampm';

  if (d == today) return 'Today at $timeStr';
  if (d == tomorrow) return 'Tomorrow at $timeStr';
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[date.month - 1]} ${date.day} at $timeStr';
}

// ─── Screen ────────────────────────────────────────────────────────────────

class CreateAudioRoomScreen extends ConsumerStatefulWidget {
  const CreateAudioRoomScreen({super.key});

  @override
  ConsumerState<CreateAudioRoomScreen> createState() => _CreateAudioRoomScreenState();
}

class _CreateAudioRoomScreenState extends ConsumerState<CreateAudioRoomScreen> {
  // ── Room data ──────────────────────────────────────────────────────────────
  Map<String, dynamic>? _liveRoom;
  List<Map<String, dynamic>> _scheduledRooms = [];
  bool _isLoading = true;

  // ── Form visibility ────────────────────────────────────────────────────────
  bool _showForm = false;
  String? _editingRoomId;
  bool _isEditingLiveRoom = false;

  // ── Form fields ────────────────────────────────────────────────────────────
  final _roomNameCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  String _username = '';
  String _usernameStatus = 'idle'; // idle | generating | available | taken
  bool _isPrivate = false;
  bool _isScheduled = false;
  bool _isScheduleIntent = false;
  DateTime? _scheduledDate;

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _isCreating = false;
  String _activeTab = 'details'; // details | admins | banned | reviews
  List<Map<String, dynamic>> _bannedUsers = [];
  bool _bannedLoading = false;
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = false;
  bool _reviewsLoadingMore = false;
  int _reviewsPage = 1;
  bool _reviewsHasMore = true;
  Map<String, dynamic>? _ratingStats;

  // ── Community groups ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> _joinedCommunities = [];
  Map<String, dynamic>? _selectedCommunity;
  bool _communityDropdownOpen = false;

  // ── Access controls ────────────────────────────────────────────────────────
  bool _canCreateAdda = true;
  bool _isVerified = false;
  bool _personalAddaEnabled = true;
  bool _communityAddaEnabled = true;

  // ── Concurrent limit ───────────────────────────────────────────────────────
  int _addaMaxConcurrent = 0;
  int _addaActiveCount = 0;

  // ── Review report ──────────────────────────────────────────────────────────
  Map<String, dynamic>? _menuReview;
  String? _reportReviewId;
  String? _reportReason;
  bool _isReporting = false;
  bool _reportSuccessVisible = false;

  // ── Alerts ─────────────────────────────────────────────────────────────────
  bool _alertVisible = false;
  String _alertTitle = '';
  String _alertMessage = '';
  String _alertType = 'info';
  VoidCallback? _alertOnConfirm;
  bool _alertShowCancel = false;
  String _alertConfirmText = 'OK';

  // ── Bottom sheets (modal state) ────────────────────────────────────────────
  bool _reviewMenuVisible = false;
  bool _reportSheetVisible = false;

  // ── Scroll ─────────────────────────────────────────────────────────────────
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _rulesCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Derived ───────────────────────────────────────────────────────────────

  bool get _hasAnyRoom => _liveRoom != null || _scheduledRooms.isNotEmpty;

  String? get _channelName {
    final lr = _liveRoom;
    if (lr != null) {
      final cn = lr['channel_name']?.toString();
      if (_isValidChannelNameFormat(cn)) return cn;
      final rid = lr['room_id']?.toString();
      if (_isValidChannelNameFormat(rid)) return rid;
    }
    for (final r in _scheduledRooms) {
      final cn = r['channel_name']?.toString();
      if (_isValidChannelNameFormat(cn)) return cn;
      final rid = r['room_id']?.toString();
      if (_isValidChannelNameFormat(rid)) return rid;
    }
    return null;
  }

  bool get _concurrentLimitReached =>
      _addaMaxConcurrent > 0 && _addaActiveCount >= _addaMaxConcurrent;

  // ─── Load data ─────────────────────────────────────────────────────────────

  Future<void> _loadInitialData() async {
    final uid = ref.read(authProvider).uid ?? '';
    setState(() => _isLoading = true);

    await Future.wait([
      _loadRoomData(),
      _loadUserAndCommunities(uid),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadRoomData() async {
    try {
      final results = await Future.wait([
        audioRoomService.getMyRoom(),
        audioRoomService.getMySchedules(),
        audioRoomService.getAddaSettings(),
      ]);

      final myRoomRes = results[0];
      final schedulesRes = results[1];
      final settingsRes = results[2];

      final roomData = myRoomRes['data'];
      Map<String, dynamic>? liveRoom;
      if (roomData is Map<String, dynamic>) {
        final status = roomData['status']?.toString();
        if (status != 'scheduled') liveRoom = roomData;
      }

      final scheduledList = (schedulesRes['data'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [];
      scheduledList.sort((a, b) {
        final da = parseDBDate(a['scheduled_at']?.toString());
        final db = parseDBDate(b['scheduled_at']?.toString());
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

      final settings = (settingsRes['data'] as Map<String, dynamic>?) ?? {};
      final personalEnabled = settings['personal_adda_enabled'] != false;
      final communityEnabled = settings['community_adda_enabled'] != false;
      final maxConcurrent = (settings['adda_max_concurrent'] as num?)?.toInt() ?? 0;
      final activeCount = (settings['adda_active_count'] as num?)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _liveRoom = liveRoom;
          _scheduledRooms = scheduledList;
          _personalAddaEnabled = personalEnabled;
          _communityAddaEnabled = communityEnabled;
          _addaMaxConcurrent = maxConcurrent;
          _addaActiveCount = activeCount;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserAndCommunities(String uid) async {
    if (uid.isEmpty) return;
    try {
      final results = await Future.wait([
        dioClient.get('/v1/user/$uid').catchError((_) => throw Exception()),
        chatApiService.getUserGroups(uid).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final userRes = results[0] as dynamic;
      final userData = userRes?.data?['data'] as Map<String, dynamic>?;
      if (userData != null) {
        final access = userData['access'] as Map<String, dynamic>?;
        final canCreate = access?['can_create_adda'];
        if (mounted) {
          setState(() {
            _canCreateAdda = canCreate == null || canCreate == true || canCreate == 1;
            _isVerified = userData['is_verified'] == true || userData['is_verified'] == 1;
          });
        }
      }

      final groups = results[1] as List<Map<String, dynamic>>;
      final filtered = groups.where((g) {
        final type = g['group_type']?.toString();
        if (type != 'public') return false;
        final role = g['user_role']?.toString();
        final isAdmin = role == 'admin' || role == 'super_admin';
        final addaEnabled = g['adda_enabled'] == true || g['adda_enabled'] == 1;
        return isAdmin || addaEnabled;
      }).toList();

      if (mounted) setState(() => _joinedCommunities = filtered);
    } catch (_) {}
  }

  // ─── Alert helpers ─────────────────────────────────────────────────────────

  void _showAlert({
    required String title,
    required String message,
    String type = 'info',
    VoidCallback? onConfirm,
    bool showCancel = false,
    String confirmText = 'OK',
  }) {
    setState(() {
      _alertVisible = true;
      _alertTitle = title;
      _alertMessage = message;
      _alertType = type;
      _alertOnConfirm = onConfirm;
      _alertShowCancel = showCancel;
      _alertConfirmText = confirmText;
    });
  }

  void _dismissAlert() => setState(() => _alertVisible = false);

  // ─── Form open/close ───────────────────────────────────────────────────────

  void _openNewLiveForm() {
    _roomNameCtrl.clear();
    _rulesCtrl.clear();
    setState(() {
      _showForm = true;
      _editingRoomId = null;
      _isScheduled = false;
      _isScheduleIntent = false;
      _isPrivate = false;
      _selectedCommunity = null;
      _communityDropdownOpen = false;
      _scheduledDate = null;
      _username = '';
      _usernameStatus = 'idle';
    });
    if (_channelName == null) _generateAndSetUsername();
  }

  void _openNewScheduleForm() {
    _roomNameCtrl.clear();
    _rulesCtrl.clear();
    setState(() {
      _showForm = true;
      _editingRoomId = null;
      _isScheduled = true;
      _isScheduleIntent = true;
      _isPrivate = false;
      _selectedCommunity = null;
      _communityDropdownOpen = false;
      _scheduledDate = null;
      _username = '';
      _usernameStatus = 'idle';
    });
    if (_channelName == null) _generateAndSetUsername();
  }

  void _openEditScheduleForm(Map<String, dynamic> room) {
    _roomNameCtrl.text = room['room_name']?.toString() ?? '';
    _rulesCtrl.text = room['rules']?.toString() ?? '';
    final isPublic = room['is_public'];
    final isPriv = isPublic == 0 || isPublic == false;
    final scheduledAt = parseDBDate(room['scheduled_at']?.toString());

    Map<String, dynamic>? community;
    final gid = room['group_id']?.toString();
    if (gid != null && gid.isNotEmpty) {
      community = _joinedCommunities.firstWhere(
        (c) => c['id']?.toString() == gid,
        orElse: () => {'id': gid, 'name': room['group_name'] ?? ''},
      );
    }

    setState(() {
      _showForm = true;
      _editingRoomId = room['room_id']?.toString();
      _isScheduled = true;
      _isScheduleIntent = false;
      _isPrivate = isPriv;
      _selectedCommunity = community;
      _scheduledDate = scheduledAt;
      _communityDropdownOpen = false;
    });
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingRoomId = null;
      _isEditingLiveRoom = false;
      _communityDropdownOpen = false;
    });
  }

  // ─── Username generation ───────────────────────────────────────────────────

  Future<void> _generateAndSetUsername() async {
    setState(() => _usernameStatus = 'generating');
    final rng = Random();
    for (int i = 0; i < 8; i++) {
      final adj = _kUsernameAdjectives[rng.nextInt(_kUsernameAdjectives.length)];
      final noun = _kUsernameNouns[rng.nextInt(_kUsernameNouns.length)];
      final candidate = '$adj$noun';
      if (candidate.length < 7 || candidate.length > 10) continue;
      try {
        final res = await audioRoomService.checkUsernameAvailability(candidate);
        if (res['available'] == true) {
          if (mounted) setState(() { _username = candidate; _usernameStatus = 'available'; });
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() { _username = ''; _usernameStatus = 'taken'; });
  }

  // ─── Validation ────────────────────────────────────────────────────────────

  bool _validateRoomForm({required bool requireUsername}) {
    if (!_isPrivate && _selectedCommunity == null) {
      _showAlert(title: 'Community Required', message: 'Please select a community to start your Adda', type: 'warning');
      return false;
    }
    if (_roomNameCtrl.text.trim().length < 5) {
      _showAlert(title: 'Too Short', message: 'Adda name must be at least 5 characters', type: 'warning');
      return false;
    }
    if (_isProfane(_roomNameCtrl.text.trim())) {
      _showAlert(title: 'Inappropriate Title', message: 'Please choose a different name for your Adda', type: 'danger');
      return false;
    }
    if (requireUsername) {
      if (_usernameStatus == 'generating') {
        _showAlert(title: 'Please Wait', message: 'Generating your username...', type: 'info');
        return false;
      }
      if (_username.isEmpty || _usernameStatus != 'available') {
        _showAlert(title: 'Username Unavailable', message: 'Could not assign a username. Please try again.', type: 'warning');
        return false;
      }
    }
    return true;
  }

  // ─── Microphone permission ─────────────────────────────────────────────────

  Future<bool> _checkMicrophonePermission() async {
    final permission = Permission.microphone;
    final status = await permission.status;
    if (status.isGranted) return true;
    if (status.isDenied || status.isLimited) {
      final result = await permission.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied) {
      _showAlert(
        title: 'Microphone Access Required',
        message: 'Please enable microphone access in your device settings to join audio rooms.',
        type: 'warning',
        showCancel: true,
        confirmText: 'Open Settings',
        onConfirm: () { _dismissAlert(); openAppSettings(); },
      );
      return false;
    }
    _showAlert(title: 'Microphone Access', message: 'Microphone access is required to participate in audio rooms.', type: 'info');
    return false;
  }

  // ─── IP fetch ──────────────────────────────────────────────────────────────

  Future<String?> _fetchFrontendIp() async {
    try {
      final res = await dioClient.get('https://api.ipify.org?format=json').timeout(const Duration(seconds: 3));
      return res.data?['ip']?.toString();
    } catch (_) {
      return null;
    }
  }

  // ─── Create room ───────────────────────────────────────────────────────────

  Future<void> _handleCreateRoom() async {
    if (!_canCreateAdda) {
      _showAlert(title: 'Access Restricted', message: 'You are not allowed to create an Adda at this time.', type: 'danger');
      return;
    }
    if (_isPrivate && !_isVerified) {
      _showAlert(title: 'Verification Required', message: 'You need to verify your account to start a Private Adda.', type: 'warning');
      return;
    }
    if (!_isPrivate && !_communityAddaEnabled) {
      _showAlert(title: 'Community Adda Unavailable', message: 'Community Addas are temporarily disabled.', type: 'info');
      return;
    }
    final requireUsername = _liveRoom == null && _channelName == null;
    if (!_validateRoomForm(requireUsername: requireUsername)) return;
    if (!await _checkMicrophonePermission()) return;

    setState(() => _isCreating = true);
    try {
      final ip = await _fetchFrontendIp();
      final existingRoomId = _liveRoom?['room_id']?.toString() ??
          (_scheduledRooms.isNotEmpty ? _scheduledRooms.first['room_id']?.toString() : null);

      final payload = <String, dynamic>{
        'room_name': _roomNameCtrl.text.trim(),
        'rules': _rulesCtrl.text.trim(),
        'is_public': _isPrivate ? 0 : 1,
        'room_id': existingRoomId ?? _username.trim(),
        'server_type': 'livekit',
        if (_selectedCommunity != null) 'group_id': _selectedCommunity!['id'],
        if (ip != null) 'frontendIp': ip,
      };

      final res = await audioRoomService.createRoom(payload);
      if (!mounted) return;

      if (res['success'] == true || res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final roomId = data['room_id']?.toString() ?? existingRoomId ?? _username;
        final roomName = data['room_name']?.toString() ?? _roomNameCtrl.text.trim();
        context.pushReplacement('/live-audio/$roomId', extra: {'room_name': roomName, 'is_host': true});
      } else {
        _showAlert(title: 'Error', message: res['message']?.toString() ?? 'Failed to create Adda', type: 'danger');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('message') ? e.toString() : 'Failed to create Adda';
        _showAlert(title: 'Error', message: msg, type: 'danger');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ─── Quick start (existing live room) ─────────────────────────────────────

  Future<void> _handleQuickStartRoom() async {
    final room = _liveRoom;
    if (room == null) return;
    if (!_canCreateAdda) {
      _showAlert(title: 'Access Restricted', message: 'You are not allowed to start an Adda right now.', type: 'danger');
      return;
    }
    final isPublic = room['is_public'] == 1 || room['is_public'] == true;
    if (isPublic && !_isVerified && room['group_id'] == null) {
      _showAlert(title: 'Verification Required', message: 'Verify your account to start a Public Adda.', type: 'warning');
      return;
    }
    final roomName = room['room_name']?.toString() ?? '';
    if (_isProfane(roomName)) {
      _showAlert(title: 'Inappropriate Title', message: 'Your room name contains inappropriate content.', type: 'danger');
      return;
    }
    if (!await _checkMicrophonePermission()) return;

    setState(() => _isCreating = true);
    try {
      final ip = await _fetchFrontendIp();
      final payload = <String, dynamic>{
        'room_name': roomName,
        'rules': room['rules']?.toString() ?? '',
        'is_public': room['is_public'],
        'room_id': room['room_id'],
        'server_type': 'livekit',
        if (room['group_id'] != null) 'group_id': room['group_id'],
        if (ip != null) 'frontendIp': ip,
      };

      final res = await audioRoomService.createRoom(payload);
      if (!mounted) return;

      if (res['success'] == true || res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final roomId = data['room_id']?.toString() ?? room['room_id']?.toString() ?? '';
        context.pushReplacement('/live-audio/$roomId', extra: {'room_name': roomName, 'is_host': true});
      } else {
        _showAlert(title: 'Error', message: res['message']?.toString() ?? 'Failed to start Adda', type: 'danger');
      }
    } catch (e) {
      if (mounted) _showAlert(title: 'Error', message: 'Failed to start Adda', type: 'danger');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ─── Schedule room ─────────────────────────────────────────────────────────

  Future<void> _handleScheduleRoom() async {
    final requireUsername = _editingRoomId == null && _channelName == null;
    if (!_validateRoomForm(requireUsername: requireUsername)) return;
    if (_scheduledDate == null) {
      _showAlert(title: 'Date Required', message: 'Please select a date and time for your Adda.', type: 'warning');
      return;
    }
    final minTime = DateTime.now().add(const Duration(minutes: _kMinScheduleMinutes));
    if (_scheduledDate!.isBefore(minTime)) {
      _showAlert(title: 'Too Soon', message: 'Schedule at least $_kMinScheduleMinutes minutes from now. Addas must also be 1 hour apart.', type: 'warning');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final payload = <String, dynamic>{
        'room_name': _roomNameCtrl.text.trim(),
        'rules': _rulesCtrl.text.trim(),
        'is_public': _isPrivate ? 0 : 1,
        'scheduled_at': _scheduledDate!.toIso8601String(),
        if (_selectedCommunity != null) 'group_id': _selectedCommunity!['id'],
      };

      if (_editingRoomId != null) {
        payload['room_id'] = _editingRoomId;
      } else if (_channelName != null) {
        payload['channel_name'] = _channelName;
      } else {
        payload['room_id'] = _username.trim();
      }

      final res = await audioRoomService.scheduleRoom(payload);
      if (!mounted) return;

      if (res['success'] == true || res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final timeStr = _formatScheduledTime(_scheduledDate!);
        if (_editingRoomId != null) {
          setState(() {
            final idx = _scheduledRooms.indexWhere((r) => r['room_id']?.toString() == _editingRoomId);
            if (idx >= 0) _scheduledRooms[idx] = data;
          });
        } else {
          setState(() {
            _scheduledRooms.add(data);
            _scheduledRooms.sort((a, b) {
              final da = parseDBDate(a['scheduled_at']?.toString());
              final db = parseDBDate(b['scheduled_at']?.toString());
              if (da == null || db == null) return 0;
              return da.compareTo(db);
            });
          });
        }
        _closeForm();
        _showAlert(title: 'Adda Scheduled!', message: 'Your Adda is scheduled for $timeStr', type: 'success');
      } else {
        _showAlert(title: 'Error', message: res['message']?.toString() ?? 'Failed to schedule Adda', type: 'danger');
      }
    } catch (e) {
      if (mounted) _showAlert(title: 'Error', message: 'Failed to schedule Adda', type: 'danger');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ─── Start scheduled room ─────────────────────────────────────────────────

  Future<void> _handleStartScheduledRoom(String roomId, String roomName) async {
    if (!_canCreateAdda) {
      _showAlert(title: 'Access Restricted', message: 'You are not allowed to start an Adda right now.', type: 'danger');
      return;
    }
    if (_isProfane(roomName)) {
      _showAlert(title: 'Inappropriate Title', message: 'Room name contains inappropriate content.', type: 'danger');
      return;
    }
    if (!await _checkMicrophonePermission()) return;

    setState(() => _isCreating = true);
    try {
      final ip = await _fetchFrontendIp();
      final res = await audioRoomService.startScheduledRoomWithIp(roomId, frontendIp: ip);
      if (!mounted) return;

      if (res['success'] == true || res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final rid = data['room_id']?.toString() ?? roomId;
        context.pushReplacement('/live-audio/$rid', extra: {'room_name': roomName, 'is_host': true});
      } else {
        _showAlert(title: 'Error', message: res['message']?.toString() ?? 'Failed to start Adda', type: 'danger');
      }
    } catch (e) {
      if (mounted) _showAlert(title: 'Error', message: 'Failed to start Adda', type: 'danger');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ─── Cancel scheduled room ────────────────────────────────────────────────

  void _handleCancelScheduledRoom(String roomId, String roomName) {
    _showAlert(
      title: 'Cancel Adda',
      message: 'Are you sure you want to cancel "$roomName"?',
      type: 'danger',
      showCancel: true,
      confirmText: 'Cancel Adda',
      onConfirm: () async {
        _dismissAlert();
        try {
          await audioRoomService.deleteScheduledRoomById(roomId);
          if (mounted) {
            setState(() => _scheduledRooms.removeWhere((r) => r['room_id']?.toString() == roomId));
          }
        } catch (_) {}
      },
    );
  }

  // ─── Update live room ──────────────────────────────────────────────────────

  Future<void> _handleUpdateRoom() async {
    final room = _liveRoom;
    if (room == null) return;
    if (_roomNameCtrl.text.trim().length < 5) {
      _showAlert(title: 'Too Short', message: 'Adda name must be at least 5 characters', type: 'warning');
      return;
    }
    if (_isProfane(_roomNameCtrl.text.trim())) {
      _showAlert(title: 'Inappropriate Title', message: 'Please choose a different name.', type: 'danger');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final payload = <String, dynamic>{
        'room_name': _roomNameCtrl.text.trim(),
        'rules': _rulesCtrl.text.trim(),
        'is_public': _isPrivate ? 0 : 1,
        'server_type': 'livekit',
        if (_selectedCommunity != null) 'group_id': _selectedCommunity!['id'],
      };

      await audioRoomService.updateRoomData(room['room_id']?.toString() ?? '', payload);
      if (!mounted) return;

      final wasPrivate = room['is_public'] == 0 || room['is_public'] == false;
      final nowPrivate = _isPrivate;
      if (wasPrivate != nowPrivate) {
        // Refetch to get new invite_token
        final refreshed = await audioRoomService.getMyRoom();
        final data = refreshed['data'];
        if (data is Map<String, dynamic> && mounted) {
          setState(() { _liveRoom = data; _isEditingLiveRoom = false; });
        }
      } else {
        setState(() {
          _liveRoom = {
            ...(room),
            'room_name': _roomNameCtrl.text.trim(),
            'rules': _rulesCtrl.text.trim(),
            'is_public': _isPrivate ? 0 : 1,
            if (_selectedCommunity != null) 'group_id': _selectedCommunity!['id'],
          };
          _isEditingLiveRoom = false;
        });
      }
    } catch (e) {
      if (mounted) _showAlert(title: 'Error', message: 'Failed to save changes', type: 'danger');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ─── Force end room ────────────────────────────────────────────────────────

  void _handleForceEndRoom() {
    _showAlert(
      title: 'End Adda',
      message: 'Force-end this Adda? This cannot be undone.',
      type: 'danger',
      showCancel: true,
      confirmText: 'End Now',
      onConfirm: () async {
        _dismissAlert();
        try {
          final roomId = _liveRoom?['room_id']?.toString() ?? '';
          await audioRoomService.forceEndRoom(roomId);
          if (mounted) {
            setState(() {
              _liveRoom = {...?_liveRoom, 'status': 'ended'};
            });
          }
        } catch (_) {}
      },
    );
  }

  // ─── Admins ────────────────────────────────────────────────────────────────

  void _handleRemoveAdmin(String adminUid, String adminName) {
    _showAlert(
      title: 'Remove Admin',
      message: 'Remove $adminName as admin?',
      type: 'warning',
      showCancel: true,
      confirmText: 'Remove',
      onConfirm: () async {
        _dismissAlert();
        try {
          final roomId = _liveRoom?['room_id']?.toString() ?? '';
          await audioRoomService.removeAdminRole(roomId, adminUid);
          if (mounted) {
            setState(() {
              final admins = List<Map<String, dynamic>>.from(
                  (_liveRoom?['admins'] as List?)?.cast<Map<String, dynamic>>() ?? []);
              admins.removeWhere((a) => a['uid']?.toString() == adminUid);
              _liveRoom = {...?_liveRoom, 'admins': admins};
            });
          }
        } catch (_) {}
      },
    );
  }

  // ─── Banned ────────────────────────────────────────────────────────────────

  Future<void> _loadBannedUsers() async {
    final roomId = _liveRoom?['room_id']?.toString() ?? '';
    if (roomId.isEmpty) return;
    setState(() => _bannedLoading = true);
    try {
      final res = await audioRoomService.getBannedUsers(roomId);
      final data = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _bannedUsers = data; _bannedLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _bannedLoading = false);
    }
  }

  void _handleUnban(String bannedUid, String name) {
    _showAlert(
      title: 'Unban User',
      message: 'Unban $name from your Adda?',
      type: 'warning',
      showCancel: true,
      confirmText: 'Unban',
      onConfirm: () async {
        _dismissAlert();
        try {
          final roomId = _liveRoom?['room_id']?.toString() ?? '';
          await audioRoomService.unbanUser(roomId, bannedUid);
          if (mounted) setState(() => _bannedUsers.removeWhere((b) => b['banned_uid']?.toString() == bannedUid));
        } catch (_) {}
      },
    );
  }

  // ─── Reviews ───────────────────────────────────────────────────────────────

  Future<void> _fetchReviews(int page) async {
    final roomId = _liveRoom?['room_id']?.toString() ?? '';
    if (roomId.isEmpty) return;
    if (page == 1) setState(() { _reviewsLoading = true; _reviews = []; _reviewsHasMore = true; });
    else setState(() => _reviewsLoadingMore = true);

    try {
      final res = await audioRoomService.getRoomReviews(roomId, page, 20);
      final data = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      data.sort((a, b) {
        final da = parseDBDate(a['created_at']?.toString());
        final db = parseDBDate(b['created_at']?.toString());
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
      final hasMore = res['pagination']?['hasMore'] == true;

      if (page == 1) {
        final aggRes = await audioRoomService.getRoomRatingAggregate(roomId);
        final aggData = aggRes['data'] as Map<String, dynamic>?;
        if (mounted) setState(() => _ratingStats = aggData);
      }

      if (mounted) {
        setState(() {
          if (page == 1) _reviews = data;
          else _reviews.addAll(data);
          _reviewsHasMore = hasMore;
          _reviewsPage = page;
          _reviewsLoading = false;
          _reviewsLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _reviewsLoading = false; _reviewsLoadingMore = false; });
    }
  }

  // ─── Tab change ────────────────────────────────────────────────────────────

  void _handleTabChange(String tab) {
    setState(() => _activeTab = tab);
    if (tab == 'banned') _loadBannedUsers();
    if (tab == 'reviews' && _liveRoom != null) _fetchReviews(1);
  }

  // ─── Report review ─────────────────────────────────────────────────────────

  Future<void> _handleSubmitReport() async {
    if (_reportReviewId == null || _reportReason == null) return;
    setState(() => _isReporting = true);
    try {
      final roomId = _liveRoom?['room_id']?.toString() ?? '';
      await audioRoomService.reportReview(roomId, _reportReviewId!, _reportReason!);
      if (mounted) {
        setState(() {
          _reportSheetVisible = false;
          _reviewMenuVisible = false;
          _isReporting = false;
          _reportSuccessVisible = true;
          _menuReview = null;
          _reportReviewId = null;
          _reportReason = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isReporting = false);
    }
  }

  // ─── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final minDate = now.add(const Duration(minutes: _kMinScheduleMinutes));
    final date = await showDatePicker(
      context: context,
      initialDate: minDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: context.colors.primary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(minDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: context.colors.primary),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = ref.watch(authProvider).uid ?? '';
    final showTabs = _liveRoom != null && !_showForm && !_isEditingLiveRoom;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(c),
                if (showTabs) _buildTabs(c),
                Expanded(child: _buildTabContent(c, isDark, uid)),
              ],
            ),
            // Alerts overlay
            if (_alertVisible)
              CustomAlertDialog(
                visible: _alertVisible,
                title: _alertTitle,
                message: _alertMessage,
                type: _alertType,
                onConfirm: _alertOnConfirm ?? _dismissAlert,
                onCancel: _dismissAlert,
                confirmText: _alertConfirmText,
                showCancel: _alertShowCancel,
              ),
            if (_reportSuccessVisible)
              CustomAlertDialog(
                visible: _reportSuccessVisible,
                title: 'Report Submitted',
                message: 'Thank you for reporting. We\'ll review this shortly.',
                type: 'success',
                onConfirm: () => setState(() => _reportSuccessVisible = false),
              ),
            // Review menu bottom sheet
            if (_reviewMenuVisible) _buildReviewMenuSheet(c),
            // Report reason sheet
            if (_reportSheetVisible) _buildReportSheet(c),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeColors c) {
    String title = 'Create Adda';
    if (_showForm) {
      if (_editingRoomId != null) title = 'Edit Scheduled Adda';
      else if (_isScheduled || _isScheduleIntent) title = 'Schedule Adda';
      else title = 'Go Live Now';
    } else if (_isEditingLiveRoom) {
      title = 'Edit Adda Details';
    } else if (_liveRoom != null) {
      title = 'Your Adda';
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: c.headerBackground,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: c.text, size: 24),
            onPressed: () {
              if (_showForm || _isEditingLiveRoom) {
                _closeForm();
              } else {
                context.pop();
              }
            },
          ),
          Expanded(
            child: Text(title,
              style: TextStyle(color: c.text, fontSize: 18, fontFamily: 'Outfit-Bold', fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ─── Tabs ──────────────────────────────────────────────────────────────────

  Widget _buildTabs(ThemeColors c) {
    final admins = (_liveRoom?['admins'] as List?)?.length ?? 0;
    final reviews = _ratingStats?['total'] as int? ?? 0;

    Widget tab(String key, String label, {int? badge, bool danger = false}) {
      final active = _activeTab == key;
      return GestureDetector(
        onTap: () => _handleTabChange(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: active ? c.primary : Colors.transparent,
              width: 2,
            )),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                style: TextStyle(
                  color: active ? c.primary : c.textSecondary,
                  fontSize: 13,
                  fontFamily: 'Outfit-SemiBold',
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: danger ? c.error : c.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Outfit-Bold')),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.headerBackground,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          tab('details', 'Details'),
          tab('reviews', 'Reviews', badge: reviews),
          tab('admins', 'Admins', badge: admins),
          tab('banned', 'Banned', danger: true),
        ],
      ),
    );
  }

  // ─── Tab content router ────────────────────────────────────────────────────

  Widget _buildTabContent(ThemeColors c, bool isDark, String uid) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }
    if (_liveRoom != null && !_showForm && !_isEditingLiveRoom) {
      switch (_activeTab) {
        case 'admins': return _buildAdminsTab(c);
        case 'banned': return _buildBannedTab(c);
        case 'reviews': return _buildReviewsTab(c, uid);
        default: return _buildDetailsTab(c, isDark);
      }
    }
    return _buildDetailsTab(c, isDark);
  }

  // ─── Details tab ──────────────────────────────────────────────────────────

  Widget _buildDetailsTab(ThemeColors c, bool isDark) {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Concurrent limit banner
          if (_concurrentLimitReached)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.warning, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Maximum $_addaMaxConcurrent live Adda(s) reached — new rooms are temporarily blocked',
                      style: TextStyle(color: c.warning, fontSize: 12, fontFamily: 'Outfit-Medium'),
                    ),
                  ),
                ],
              ),
            ),

          if (_showForm) ...[
            _buildForm(c, isDark),
          ] else ...[
            // Quick-start card
            if (_liveRoom != null && !_isEditingLiveRoom)
              _buildQuickStartCard(c, isDark),

            // Inline edit form
            if (_liveRoom != null && _isEditingLiveRoom)
              _buildInlineEditForm(c, isDark),

            // Scheduled rooms
            if (_scheduledRooms.isNotEmpty && !_isEditingLiveRoom)
              _buildScheduledSection(c),

            // Empty state
            if (_liveRoom == null && _scheduledRooms.isEmpty)
              _buildEmptyState(c),

            // Action rows
            if (!_isEditingLiveRoom && (_liveRoom != null || _scheduledRooms.isNotEmpty))
              _buildActionRows(c),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Quick-start card ──────────────────────────────────────────────────────

  Widget _buildQuickStartCard(ThemeColors c, bool isDark) {
    final room = _liveRoom!;
    final roomName = room['room_name']?.toString() ?? '';
    final isRunning = room['status']?.toString() == 'active';
    final isPublic = room['is_public'] == 1 || room['is_public'] == true;
    final channelName = room['channel_name']?.toString() ?? room['room_id']?.toString() ?? '';
    final groupId = room['group_id']?.toString();
    final linkedCommunity = groupId != null && groupId.isNotEmpty
        ? _joinedCommunities.firstWhere((c2) => c2['id']?.toString() == groupId, orElse: () => <String, dynamic>{})
        : null;
    final communityName = linkedCommunity?['name']?.toString() ?? room['group_name']?.toString();
    final showCommunityBadge = linkedCommunity != null && isPublic;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: isRunning ? Border.all(color: Colors.redAccent, width: 1.5) : Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (showCommunityBadge && communityName != null)
                        _communityBadge(communityName, room['group_picture']?.toString(), c)
                      else
                        _personalBadge(c),
                      if (isRunning)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text('Live', style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Outfit-Bold')),
                          ]),
                        ),
                      _visibilityBadge(isPublic, c),
                    ],
                  ),
                ),
                if (!isRunning)
                  GestureDetector(
                    onTap: () {
                      _roomNameCtrl.text = roomName;
                      _rulesCtrl.text = room['rules']?.toString() ?? '';
                      setState(() {
                        _isEditingLiveRoom = true;
                        _isPrivate = !isPublic;
                        _selectedCommunity = linkedCommunity != null && linkedCommunity.isNotEmpty ? linkedCommunity : null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.edit_outlined, color: c.textSecondary, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(roomName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.text, fontSize: 20, fontFamily: 'Outfit-Bold', fontWeight: FontWeight.bold),
            ),
          ),
          if (channelName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text('@$channelName',
                style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit-Regular'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Divider(color: c.border, height: 1),
          ),
          if (!_communityAddaEnabled && isPublic)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Community Addas are temporarily unavailable.',
                  style: TextStyle(color: c.warning, fontSize: 12, fontFamily: 'Outfit-Medium')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: isRunning
                ? Row(
                    children: [
                      Expanded(
                        child: _primaryButton(
                          label: 'Rejoin Adda',
                          icon: Icons.mic,
                          onPressed: _isCreating ? null : () {
                            final roomId = room['room_id']?.toString() ?? '';
                            context.push('/live-audio/$roomId', extra: {'room_name': roomName, 'is_host': true});
                          },
                          c: c,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _handleForceEndRoom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.error.withValues(alpha: 0.4)),
                          ),
                          child: Text('End', style: TextStyle(color: c.error, fontFamily: 'Outfit-SemiBold', fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                    ],
                  )
                : _primaryButton(
                    label: 'Start Adda',
                    icon: Icons.mic,
                    onPressed: (_isCreating || _concurrentLimitReached || (!_communityAddaEnabled && isPublic))
                        ? null
                        : _handleQuickStartRoom,
                    c: c,
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Inline edit form (live room) ──────────────────────────────────────────

  Widget _buildInlineEditForm(ThemeColors c, bool isDark) {
    final room = _liveRoom!;
    final isPublic = !_isPrivate;
    final inviteToken = room['invite_token']?.toString() ?? room['room_id']?.toString() ?? '';
    final shareUrl = 'https://witalk.in/adda/$inviteToken';
    final cn = _channelName ?? room['channel_name']?.toString() ?? room['room_id']?.toString() ?? '';
    final rulesLocked = room['rules_locked'] == true || room['rules_locked'] == 1;
    final visibilityLocked = room['visibility_locked'] == true || room['visibility_locked'] == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _readOnlyField(label: 'Username', value: '@$cn', c: c),
        const SizedBox(height: 12),
        if (isPublic) ...[
          _labelText('Share Link', c),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: shareUrl)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
              child: Row(
                children: [
                  Expanded(child: Text(shareUrl, style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit-Regular'), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Icon(Icons.copy, color: c.primary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _buildCommunityDropdown(c, inlineEdit: true),
        const SizedBox(height: 12),
        _buildRoomNameField(c),
        const SizedBox(height: 12),
        if (isPublic) ...[
          _buildRulesField(c, rulesLocked: rulesLocked),
          const SizedBox(height: 12),
        ],
        if (!visibilityLocked) ...[
          _buildVisibilityToggle(c, forEdit: true),
          const SizedBox(height: 12),
        ],
        _primaryButton(label: 'Save Changes', icon: Icons.check, onPressed: _isCreating ? null : _handleUpdateRoom, c: c),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _isEditingLiveRoom = false),
          child: Center(child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit-Medium'))),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── Scheduled section ────────────────────────────────────────────────────

  Widget _buildScheduledSection(ThemeColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Scheduled Addas',
              style: TextStyle(color: c.text, fontSize: 15, fontFamily: 'Outfit-SemiBold', fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Text('${_scheduledRooms.length}/$_kMaxScheduled',
                style: TextStyle(color: c.primary, fontSize: 11, fontFamily: 'Outfit-Bold')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._scheduledRooms.map((room) => _buildScheduledCard(room, c)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildScheduledCard(Map<String, dynamic> room, ThemeColors c) {
    final roomName = room['room_name']?.toString() ?? '';
    final roomId = room['room_id']?.toString() ?? '';
    final scheduledAt = parseDBDate(room['scheduled_at']?.toString());
    final followerCount = (room['follower_count'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (scheduledAt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule, size: 13, color: c.primary),
                const SizedBox(width: 4),
                Text(_formatScheduledTime(scheduledAt),
                  style: TextStyle(color: c.primary, fontSize: 12, fontFamily: 'Outfit-SemiBold')),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roomName,
                        style: TextStyle(color: c.text, fontSize: 15, fontFamily: 'Outfit-SemiBold', fontWeight: FontWeight.w600),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text('@$roomId', style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit-Regular')),
                      if (followerCount > 0) ...[
                        const SizedBox(height: 3),
                        Text('$followerCount following',
                          style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    GestureDetector(
                      onTap: _isCreating ? null : () => _handleStartScheduledRoom(roomId, roomName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                        child: Text('Start', style: const TextStyle(color: Colors.white, fontFamily: 'Outfit-SemiBold', fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _openEditScheduleForm(room),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.edit_outlined, color: c.textSecondary, size: 16),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _handleCancelScheduledRoom(roomId, roomName),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: c.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.delete_outline, color: c.error, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeColors c) {
    final hasCommunities = _joinedCommunities.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(hasCommunities ? Icons.mic : Icons.group, size: 36, color: c.primary),
          ),
          const SizedBox(height: 16),
          Text(
            hasCommunities ? 'Start a Community Adda' : 'Join a Community First',
            style: TextStyle(color: c.text, fontSize: 18, fontFamily: 'Outfit-Bold', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            hasCommunities
                ? 'Go live in one of your communities and connect with members.'
                : 'Join a public community to start hosting Addas.',
            style: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'Outfit-Regular'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (!hasCommunities)
            GestureDetector(
              onTap: () => context.push('/communities'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.primary.withValues(alpha: 0.4)),
                ),
                child: Text('Explore Communities', style: TextStyle(color: c.primary, fontFamily: 'Outfit-SemiBold', fontWeight: FontWeight.w600)),
              ),
            )
          else if (_communityAddaEnabled)
            _primaryButton(label: 'Go Live in a Community', icon: Icons.mic, onPressed: _openNewLiveForm, c: c, fullWidth: false),
        ],
      ),
    );
  }

  // ─── Action rows ───────────────────────────────────────────────────────────

  Widget _buildActionRows(ThemeColors c) {
    return Column(
      children: [
        const SizedBox(height: 8),
        if (_liveRoom == null && _communityAddaEnabled)
          _actionRow(
            icon: Icons.mic,
            title: 'Go Live Now',
            desc: 'Start a live community Adda instantly',
            onTap: _openNewLiveForm,
            c: c,
          ),
        if (_scheduledRooms.length < _kMaxScheduled)
          _actionRow(
            icon: Icons.event,
            title: 'Schedule New Adda',
            desc: 'Plan ahead — let your followers know',
            onTap: _openNewScheduleForm,
            c: c,
            trailing: Text('${_scheduledRooms.length}/$_kMaxScheduled',
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit-Regular')),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Maximum $_kMaxScheduled scheduled Addas reached',
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit-Regular'),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
    required ThemeColors c,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: c.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit-SemiBold', fontWeight: FontWeight.w600)),
                  Text(desc, style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit-Regular')),
                ],
              ),
            ),
            if (trailing != null) trailing
            else Icon(Icons.chevron_right, color: c.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Form ─────────────────────────────────────────────────────────────────

  Widget _buildForm(ThemeColors c, bool isDark) {
    final requireUsername = _editingRoomId == null && _channelName == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommunityDropdown(c),
        const SizedBox(height: 12),
        if (!_isPrivate) ...[
          _buildRoomNameField(c),
          const SizedBox(height: 12),
          _buildRulesField(c, rulesLocked: false),
          const SizedBox(height: 12),
        ],
        if (!_isScheduled && _editingRoomId == null)
          _buildVisibilityToggle(c),
        if (_editingRoomId == null && !_isScheduleIntent) ...[
          const SizedBox(height: 12),
          _buildWhenToggle(c),
        ],
        if (_isScheduled || _editingRoomId != null) ...[
          const SizedBox(height: 12),
          _buildDatePickerRow(c),
        ],
        if (requireUsername && _usernameStatus != 'idle') ...[
          const SizedBox(height: 8),
          _usernameStatusRow(c),
        ],
        const SizedBox(height: 20),
        _primaryButton(
          label: _editingRoomId != null ? 'Save Changes' : (_isScheduled ? 'Schedule Adda' : 'Go Live Now'),
          icon: _isScheduled ? Icons.event : Icons.mic,
          onPressed: _isCreating
              ? null
              : (_editingRoomId != null ? _handleScheduleRoom : (_isScheduled ? _handleScheduleRoom : _handleCreateRoom)),
          c: c,
          loading: _isCreating,
        ),
      ],
    );
  }

  Widget _buildCommunityDropdown(ThemeColors c, {bool inlineEdit = false}) {
    if (_isPrivate && !inlineEdit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelText('Community', c),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Icon(Icons.person, color: const Color(0xFF9C27B0), size: 20),
              const SizedBox(width: 8),
              Text('Personal Adda', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit-Medium')),
            ]),
          ),
          const SizedBox(height: 4),
          Text('Personal Addas are only for verified users',
            style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText('Community', c),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _communityDropdownOpen = !_communityDropdownOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _communityDropdownOpen ? c.primary : c.border),
            ),
            child: Row(
              children: [
                if (_selectedCommunity != null) ...[
                  _communityAvatar(_selectedCommunity!['picture']?.toString(), _selectedCommunity!['name']?.toString() ?? '', 20, c),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _selectedCommunity?['name']?.toString() ?? 'Select a community...',
                    style: TextStyle(
                      color: _selectedCommunity != null ? c.text : c.placeholder,
                      fontFamily: 'Outfit-Regular',
                    ),
                  ),
                ),
                Icon(_communityDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: c.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        if (_communityDropdownOpen) _buildDropdownList(c),
        if (!_communityDropdownOpen)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Adda will be linked to this community',
              style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
          ),
      ],
    );
  }

  Widget _buildDropdownList(ThemeColors c) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ..._joinedCommunities.map((community) {
            final isSelected = _selectedCommunity?['id']?.toString() == community['id']?.toString();
            return GestureDetector(
              onTap: () => setState(() {
                _selectedCommunity = community;
                _communityDropdownOpen = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: isSelected ? c.primary.withValues(alpha: 0.1) : Colors.transparent,
                child: Row(children: [
                  _communityAvatar(community['picture']?.toString(), community['name']?.toString() ?? '', 28, c),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(community['name']?.toString() ?? '',
                          style: TextStyle(
                            color: isSelected ? c.primary : c.text,
                            fontFamily: 'Outfit-SemiBold',
                            fontSize: 13,
                          ),
                        ),
                        if (community['member_count'] != null)
                          Text('${community['member_count']} members',
                            style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
                      ],
                    ),
                  ),
                  if (isSelected) Icon(Icons.check, color: c.primary, size: 18),
                ]),
              ),
            );
          }),
          GestureDetector(
            onTap: () { setState(() => _communityDropdownOpen = false); context.push('/communities'); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Row(children: [
                Icon(Icons.explore_outlined, color: c.primary, size: 16),
                const SizedBox(width: 8),
                Text('Explore more communities', style: TextStyle(color: c.primary, fontFamily: 'Outfit-Medium', fontSize: 13)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomNameField(ThemeColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _labelText('Adda Topic', c),
          const Spacer(),
          Text('${_roomNameCtrl.text.length}/100', style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _roomNameCtrl,
          maxLength: 100,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: c.text, fontFamily: 'Outfit-Regular'),
          decoration: InputDecoration(
            hintText: "What's your adda about?",
            hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit-Regular'),
            counterText: '',
            filled: true, fillColor: c.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildRulesField(ThemeColors c, {required bool rulesLocked}) {
    final topic = _roomNameCtrl.text.trim();
    final showAutoSuggest = topic.isNotEmpty && !rulesLocked && _selectedCommunity == null;
    final isDisabled = rulesLocked || _selectedCommunity != null;

    String helperText;
    if (rulesLocked) helperText = 'Rules are locked by admin';
    else if (_selectedCommunity != null) helperText = 'Community rules will apply';
    else helperText = '${_rulesCtrl.text.length}/500';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _labelText('Room Rules', c),
          Text(' (optional)', style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
          const Spacer(),
          if (showAutoSuggest)
            GestureDetector(
              onTap: () {
                setState(() => _rulesCtrl.text = _generateRulesForTopic(topic));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Auto-suggest', style: TextStyle(color: c.primary, fontSize: 11, fontFamily: 'Outfit-SemiBold')),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _rulesCtrl,
          maxLines: 4,
          maxLength: 500,
          enabled: !isDisabled,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: c.text, fontFamily: 'Outfit-Regular'),
          decoration: InputDecoration(
            hintText: 'Optional: set room rules for participants...',
            hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit-Regular'),
            counterText: '',
            filled: true, fillColor: isDisabled ? c.surface.withValues(alpha: 0.5) : c.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primary, width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border.withValues(alpha: 0.5))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 4),
        Text(helperText, style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
      ],
    );
  }

  Widget _buildVisibilityToggle(ThemeColors c, {bool forEdit = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText('Visibility', c),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _modeBtn(label: 'Public', icon: Icons.public, selected: !_isPrivate, onTap: () {
              setState(() { _isPrivate = false; });
            }, c: c)),
            const SizedBox(width: 8),
            Expanded(child: _modeBtn(
              label: 'Private',
              icon: Icons.lock_outline,
              selected: _isPrivate,
              onTap: () {
                if (!_isVerified) {
                  _showAlert(title: 'Verification Required', message: 'You need to verify your account to create a Private Adda.', type: 'warning');
                  return;
                }
                setState(() {
                  _isPrivate = true;
                  _roomNameCtrl.text = 'WiTalk Private Adda';
                  _selectedCommunity = null;
                  _rulesCtrl.clear();
                });
              },
              c: c,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildWhenToggle(ThemeColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText('When', c),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _modeBtn(label: 'Start Now', icon: Icons.play_arrow, selected: !_isScheduled, onTap: () {
              setState(() => _isScheduled = false);
            }, c: c)),
            const SizedBox(width: 8),
            Expanded(child: Opacity(
              opacity: _isVerified ? 1.0 : 0.45,
              child: _modeBtn(label: 'Schedule', icon: Icons.event, selected: _isScheduled, onTap: () {
                if (!_isVerified) {
                  _showAlert(title: 'Verification Required', message: 'You need to verify your account to schedule Addas.', type: 'warning');
                  return;
                }
                setState(() => _isScheduled = true);
              }, c: c),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePickerRow(ThemeColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText('Scheduled Time', c),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: c.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  _scheduledDate == null ? 'Select date & time...' : _formatScheduledTime(_scheduledDate!),
                  style: TextStyle(
                    color: _scheduledDate == null ? c.placeholder : c.text,
                    fontFamily: 'Outfit-Regular',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('Minimum $_kMinScheduleMinutes minutes from now · Addas must be 1 hour apart',
          style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
      ],
    );
  }

  Widget _usernameStatusRow(ThemeColors c) {
    if (_usernameStatus == 'generating') {
      return Row(children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
        const SizedBox(width: 8),
        Text('Generating username...', style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit-Regular')),
      ]);
    }
    if (_usernameStatus == 'available') {
      return Row(children: [
        Icon(Icons.check_circle, color: c.success, size: 16),
        const SizedBox(width: 6),
        Text('@$_username', style: TextStyle(color: c.success, fontSize: 12, fontFamily: 'Outfit-SemiBold')),
      ]);
    }
    if (_usernameStatus == 'taken') {
      return Row(children: [
        Icon(Icons.error_outline, color: c.error, size: 16),
        const SizedBox(width: 6),
        Text('Could not generate username', style: TextStyle(color: c.error, fontSize: 12, fontFamily: 'Outfit-Regular')),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _generateAndSetUsername,
          child: Text('Retry', style: TextStyle(color: c.primary, fontSize: 12, fontFamily: 'Outfit-SemiBold')),
        ),
      ]);
    }
    return const SizedBox.shrink();
  }

  // ─── Admins tab ────────────────────────────────────────────────────────────

  Widget _buildAdminsTab(ThemeColors c) {
    final admins = (_liveRoom?['admins'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (admins.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline, size: 48, color: c.textSecondary),
          const SizedBox(height: 12),
          Text('No Admins Yet', style: TextStyle(color: c.text, fontSize: 16, fontFamily: 'Outfit-SemiBold')),
          const SizedBox(height: 6),
          Text('Promote participants to admin from the live room', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit-Regular'), textAlign: TextAlign.center),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: admins.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final admin = admins[i];
        final name = admin['name']?.toString() ?? '';
        final username = admin['username']?.toString() ?? '';
        final uid = admin['uid']?.toString() ?? '';
        final pic = getProfileImageUrl(admin);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Row(
            children: [
              _avatarWidget(pic, name, 40, c),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 14)),
                  Text('@$username', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit-Regular', fontSize: 12)),
                ]),
              ),
              GestureDetector(
                onTap: () => _handleRemoveAdmin(uid, name),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: c.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.close, color: c.error, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Banned tab ────────────────────────────────────────────────────────────

  Widget _buildBannedTab(ThemeColors c) {
    if (_bannedLoading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }
    if (_bannedUsers.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block, size: 48, color: c.textSecondary),
          const SizedBox(height: 12),
          Text('No Banned Users', style: TextStyle(color: c.text, fontSize: 16, fontFamily: 'Outfit-SemiBold')),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _bannedUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final user = _bannedUsers[i];
        final name = user['name']?.toString() ?? '';
        final username = user['username']?.toString() ?? '';
        final uid = user['banned_uid']?.toString() ?? '';
        final pic = getProfileImageUrl(user);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.error, width: 2)),
                child: _avatarWidget(pic, name, 40, c),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 14)),
                  Text('@$username', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit-Regular', fontSize: 12)),
                ]),
              ),
              GestureDetector(
                onTap: () => _handleUnban(uid, name),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: c.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.lock_open_outlined, color: c.success, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Reviews tab ───────────────────────────────────────────────────────────

  Widget _buildReviewsTab(ThemeColors c, String uid) {
    if (_reviewsLoading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification && n.metrics.extentAfter < 200 && _reviewsHasMore && !_reviewsLoadingMore) {
          _fetchReviews(_reviewsPage + 1);
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_ratingStats != null && (_ratingStats!['total'] as int? ?? 0) > 0)
            _buildRatingOverview(c),
          if (_reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_border, size: 48, color: c.textSecondary),
                const SizedBox(height: 12),
                Text('No Reviews Yet', style: TextStyle(color: c.text, fontSize: 16, fontFamily: 'Outfit-SemiBold')),
              ]),
            )
          else
            ..._reviews.map((r) => _buildReviewItem(r, c, uid)),
          if (_reviewsLoadingMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingOverview(ThemeColors c) {
    final stats = _ratingStats!;
    final avg = double.tryParse(stats['average']?.toString() ?? '0') ?? 0.0;
    final total = (stats['total'] as int?) ?? 0;
    final dist = (stats['distribution'] as Map?)?.cast<String, dynamic>() ?? {};
    final topTags = (stats['topTags'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Text(avg.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 40, fontFamily: 'Outfit-Bold', fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) => Icon(
                      i < avg.round() ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFF9800), size: 16,
                    )),
                  ),
                  const SizedBox(height: 2),
                  Text('$total review${total != 1 ? 's' : ''}',
                    style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final star = 5 - i;
                    final count = (dist['$star'] as int?) ?? 0;
                    final pct = total > 0 ? count / total : 0.0;
                    Color barColor;
                    if (star >= 4) barColor = Colors.green;
                    else if (star == 3) barColor = Colors.orange;
                    else barColor = Colors.red;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Text('$star', style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
                        Icon(Icons.star, size: 11, color: c.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct, minHeight: 6,
                              backgroundColor: c.border,
                              valueColor: AlwaysStoppedAnimation(barColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(width: 20, child: Text('$count', style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular'), textAlign: TextAlign.right)),
                      ]),
                    );
                  }),
                ),
              ),
            ],
          ),
          if (topTags.isNotEmpty) ...[
            Divider(color: c.border, height: 20),
            Align(alignment: Alignment.centerLeft, child: Text("What people are saying", style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit-SemiBold'))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: topTags.map((t) {
                final tag = t['tag']?.toString() ?? '';
                final count = (t['count'] as int?) ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('$tag · $count', style: TextStyle(color: c.primary, fontSize: 12, fontFamily: 'Outfit-Medium')),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review, ThemeColors c, String currentUid) {
    final reviewId = review['id']?.toString() ?? review['review_id']?.toString() ?? '';
    final reviewUid = review['uid']?.toString() ?? '';
    final name = review['name']?.toString() ?? '';
    final displayName = name.isNotEmpty ? '${name[0]}***' : '?***';
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final text = review['review']?.toString() ?? '';
    final createdAt = parseDBDate(review['created_at']?.toString());
    final tags = (review['tags'] as List?)?.cast<String>() ?? [];
    final isOwn = reviewUid == currentUid;

    String dateStr = '';
    if (createdAt != null) {
      dateStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/defaultavatar.png', width: 36, height: 36, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 13)),
                    if (dateStr.isNotEmpty)
                      Text(dateStr, style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
                  ],
                ),
              ),
              if (isOwn)
                GestureDetector(
                  onTap: () {
                    _showAlert(
                      title: 'Delete Review',
                      message: 'Delete your review?',
                      type: 'danger',
                      showCancel: true,
                      confirmText: 'Delete',
                      onConfirm: () async {
                        _dismissAlert();
                        try {
                          final roomId = _liveRoom?['room_id']?.toString() ?? '';
                          await audioRoomService.deleteRoomReview(roomId, reviewId);
                          if (mounted) setState(() => _reviews.removeWhere((r) => (r['id']?.toString() ?? r['review_id']?.toString()) == reviewId));
                        } catch (_) {}
                      },
                    );
                  },
                  child: Icon(Icons.delete_outline, color: c.error, size: 20),
                )
              else
                GestureDetector(
                  onTap: () => setState(() {
                    _menuReview = review;
                    _reportReviewId = reviewId;
                    _reviewMenuVisible = true;
                  }),
                  child: Icon(Icons.more_vert, color: c.textSecondary, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) => Icon(
              i < rating ? Icons.star : Icons.star_border,
              color: const Color(0xFFFF9800), size: 16,
            )),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(text, style: TextStyle(color: c.text, fontSize: 13, fontFamily: 'Outfit-Regular', height: 1.4)),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
                child: Text(t, style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'Outfit-Regular')),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Review menu bottom sheet ──────────────────────────────────────────────

  Widget _buildReviewMenuSheet(ThemeColors c) {
    return GestureDetector(
      onTap: () => setState(() { _reviewMenuVisible = false; _menuReview = null; }),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(color: c.bottomSheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() { _reviewMenuVisible = false; _reportSheetVisible = true; _reportReason = null; });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(children: [
                        Icon(Icons.flag_outlined, color: c.error, size: 20),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Flag as inappropriate', style: TextStyle(color: c.text, fontFamily: 'Outfit-SemiBold', fontSize: 14)),
                          Text('Report this review', style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit-Regular', fontSize: 12)),
                        ]),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Report sheet ──────────────────────────────────────────────────────────

  Widget _buildReportSheet(ThemeColors c) {
    return GestureDetector(
      onTap: () => setState(() { _reportSheetVisible = false; _menuReview = null; }),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(color: c.bottomSheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Report Review', style: TextStyle(color: c.text, fontSize: 17, fontFamily: 'Outfit-Bold', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Why are you reporting this review?', style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit-Regular')),
                  const SizedBox(height: 16),
                  ..._kReportReasons.map((r) {
                    final key = r['key']!;
                    final label = r['label']!;
                    final selected = _reportReason == key;
                    return GestureDetector(
                      onTap: () => setState(() => _reportReason = key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: selected ? c.primary : c.border, width: 2),
                            ),
                            child: selected ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle))) : null,
                          ),
                          const SizedBox(width: 12),
                          Text(label, style: TextStyle(color: c.text, fontSize: 14, fontFamily: 'Outfit-Regular')),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_reportReason == null || _isReporting) ? null : _handleSubmitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        disabledBackgroundColor: c.primaryButtonDisabled,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isReporting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Report', style: TextStyle(color: Colors.white, fontFamily: 'Outfit-SemiBold', fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _labelText(String label, ThemeColors c) =>
      Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'Outfit-SemiBold', fontWeight: FontWeight.w600));

  Widget _readOnlyField({required String label, required String value, required ThemeColors c}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _labelText(label, c),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: c.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
        child: Row(children: [
          Expanded(child: Text(value, style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit-Regular'))),
        ]),
      ),
    ]);
  }

  Widget _modeBtn({required String label, required IconData icon, required bool selected, required VoidCallback onTap, required ThemeColors c}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? c.primary : c.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : c.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: selected ? Colors.white : c.textSecondary, fontFamily: 'Outfit-SemiBold', fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required ThemeColors c,
    bool loading = false,
    bool fullWidth = true,
  }) {
    final btn = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? c.primary : c.primaryButtonDisabled,
        foregroundColor: Colors.white,
        minimumSize: fullWidth ? const Size(double.infinity, 50) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontFamily: 'Outfit-Bold', fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  Widget _communityBadge(String name, String? picUrl, ThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _communityAvatar(picUrl, name, 16, c),
        const SizedBox(width: 5),
        Text(name, style: TextStyle(color: c.primary, fontSize: 11, fontFamily: 'Outfit-SemiBold'), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _personalBadge(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF9C27B0).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person, size: 12, color: Color(0xFF9C27B0)),
        const SizedBox(width: 4),
        const Text('Personal', style: TextStyle(color: Color(0xFF9C27B0), fontSize: 11, fontFamily: 'Outfit-SemiBold')),
      ]),
    );
  }

  Widget _visibilityBadge(bool isPublic, ThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublic ? c.primary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isPublic ? Icons.public : Icons.lock_outline, size: 12, color: isPublic ? c.primary : c.textSecondary),
        const SizedBox(width: 4),
        Text(isPublic ? 'Public' : 'Private',
          style: TextStyle(color: isPublic ? c.primary : c.textSecondary, fontSize: 11, fontFamily: 'Outfit-SemiBold')),
      ]),
    );
  }

  Widget _communityAvatar(String? url, String name, double size, ThemeColors c) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _avatarFallback(name, size, c)),
      );
    }
    return _avatarFallback(name, size, c);
  }

  Widget _avatarFallback(String name, double size, ThemeColors c) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Center(child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: c.primary, fontFamily: 'Outfit-Bold', fontSize: size * 0.45),
      )),
    );
  }

  Widget _avatarWidget(String? url, String name, double size, ThemeColors c) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _avatarFallback(name, size, c)),
      );
    }
    return _avatarFallback(name, size, c);
  }
}
