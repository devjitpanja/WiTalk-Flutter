import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../providers/user_provider.dart';
import '../../services/location_service.dart';
import '../../services/upload_service.dart';
import '../../utils/analytics.dart';
import '../../widgets/common/global_upload_progress.dart';
import '../../widgets/common/custom_alert_dialog.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final String? postId;
  final String? initialContent;
  final List<Map<String, dynamic>>? capturedMedia;
  final bool fromCamera;
  final bool thoughtsMode;

  const CreatePostScreen({
    super.key,
    this.isEditing = false,
    this.postId,
    this.initialContent,
    this.capturedMedia,
    this.fromCamera = false,
    this.thoughtsMode = false,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  final List<File> _selectedImages = [];
  final List<Map<String, dynamic>> _selectedImagesMeta = [];
  File? _selectedVideo;
  int _selectedVideoDuration = 0;
  int? _selectedVideoWidth;
  int? _selectedVideoHeight;

  VideoPlayerController? _videoPlayerController;
  bool _showVideoPreviewModal = false;
  bool _isVideoPlaying = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

  bool _uploading = false;
  bool _isSubmitting = false;
  String? _uid;
  Map<String, dynamic>? _userProfile;
  CachedLocation? _userLocation;

  int _cursorPosition = 0;
  List<dynamic> _popularHashtags = [];
  List<dynamic> _hashtagSuggestions = [];
  bool _showHashtagSuggestions = false;
  Timer? _hashtagDebounce;

  List<dynamic> _mentionSuggestions = [];
  bool _showMentionSuggestions = false;
  Timer? _mentionDebounce;

  bool _alertVisible = false;
  String _alertTitle = '';
  String _alertMessage = '';
  String _alertType = 'info';
  List<DialogButtonConfig> _alertButtons = [];

  static const int _maxImages = 20;
  static const int _maxCharacterCount = 1000;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _contentCtrl.text = widget.initialContent!;
    }
    _loadUser();
    _loadPopularHashtags();
    _resolveLocation();
    _checkUploadLimitOnInit();

    if (widget.capturedMedia != null && widget.fromCamera) {
      _processCapturedMedia(widget.capturedMedia!);
    }

    if (widget.thoughtsMode) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _contentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contentFocusNode.dispose();
    _hashtagDebounce?.cancel();
    _mentionDebounce?.cancel();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  // ── Alert ─────────────────────────────────────────────────────────────────────

  void _showAlert({
    required String title,
    required String message,
    String type = 'info',
    List<DialogButtonConfig>? buttons,
  }) {
    if (!mounted) return;
    setState(() {
      _alertTitle = title;
      _alertMessage = message;
      _alertType = type;
      _alertButtons = buttons ??
          [
            DialogButtonConfig(
              text: 'OK',
              onPress: () => setState(() => _alertVisible = false),
            )
          ];
      _alertVisible = true;
    });
  }

  void _dismissAlert() => setState(() => _alertVisible = false);

  // ── Init helpers ──────────────────────────────────────────────────────────────

  Future<void> _checkUploadLimitOnInit() async {
    if (_uid == null) {
      final prefs = await _prefs();
      _uid = prefs.getString('uid');
    }
    if (_uid == null) return;
    try {
      final res = await dioClient.get('/v1/config/upload-limit/$_uid');
      if (res.data != null && res.data['can_upload'] == false && mounted) {
        _showAlert(
          title: 'Upload Limit Reached',
          message:
              'You have reached your daily upload limit of ${res.data['daily_limit']} posts. Please try again tomorrow.',
          type: 'danger',
          buttons: [
            DialogButtonConfig(
              text: 'OK',
              onPress: () {
                _dismissAlert();
                if (mounted) context.pop();
              },
            ),
          ],
        );
      }
    } catch (_) {}
  }

  void _processCapturedMedia(List<Map<String, dynamic>> mediaList) {
    for (final item in mediaList) {
      final type = item['type'] as String?;
      final uri = item['uri'] as String?;
      if (uri == null) continue;
      final file = File(uri);

      if (type == 'video') {
        setState(() {
          _selectedVideo = file;
          _selectedVideoDuration = (item['duration'] as num?)?.toInt() ?? 0;
          _selectedVideoWidth = (item['width'] as num?)?.toInt();
          _selectedVideoHeight = (item['height'] as num?)?.toInt();
          _selectedImages.clear();
          _selectedImagesMeta.clear();
        });
        _initVideoPreviewPlayer(file);
        break;
      } else if (type == 'image') {
        if (_selectedImages.length < _maxImages) {
          setState(() {
            _selectedImages.add(file);
            _selectedImagesMeta.add({
              'width': (item['width'] as num?)?.toInt() ?? 0,
              'height': (item['height'] as num?)?.toInt() ?? 0,
            });
            _selectedVideo = null;
          });
        }
      }
    }
  }

  Future<void> _loadUser() async {
    // Prefer the app-wide cached profile — no network round-trip needed.
    final cached = ref.read(userProvider);
    if (cached != null) {
      _uid = cached.id;
      // Set directly — may be called from initState before first build, so
      // assign the field first; setState below is a no-op if not yet mounted.
      _userProfile = cached.toJson();
      if (mounted) setState(() {});
      // Refresh in background so data stays fresh without blocking the UI.
      ref.read(userProvider.notifier).fetchAndCache(cached.id);
      return;
    }

    // Fallback: profile not yet in provider (cold start race). Fetch directly.
    final prefs = await _prefs();
    _uid = prefs.getString('uid');
    if (_uid != null) {
      try {
        final res = await dioClient.get('/v1/user/$_uid');
        if (res.data != null && res.data['data'] != null && mounted) {
          final data = res.data['data'] as Map<String, dynamic>;
          setState(() => _userProfile = data);
          // Populate provider so subsequent screens benefit.
          ref.read(userProvider.notifier).setUser(UserProfile.fromJson(data));
        }
      } catch (_) {}
    }
  }

  // Cached prefs accessor — avoids repeated getInstance() calls.
  static SharedPreferences? _cachedPrefs;
  static Future<SharedPreferences> _prefs() async =>
      _cachedPrefs ??= await SharedPreferences.getInstance();

  Future<void> _loadPopularHashtags() async {
    try {
      final res = await dioClient.get('/v1/hashtags/popular?limit=15');
      if (res.data != null && res.data['data']?['hashtags'] != null && mounted) {
        setState(() => _popularHashtags = res.data['data']['hashtags']);
      }
    } catch (_) {}
  }

  Future<void> _resolveLocation() async {
    try {
      final loc = await locationService.getLocation();
      if (mounted) setState(() => _userLocation = loc);
    } catch (_) {}
  }

  // ── Content change / autocomplete ────────────────────────────────────────────

  void _onContentChanged(String text) {
    _hashtagDebounce?.cancel();
    _mentionDebounce?.cancel();

    final pos = _contentCtrl.selection.isValid
        ? _contentCtrl.selection.baseOffset
        : text.length;
    _cursorPosition = pos.clamp(0, text.length);
    final textBeforeCursor = text.substring(0, _cursorPosition);

    final mentionMatch =
        RegExp(r'@([a-zA-Z0-9_\.]*)$').firstMatch(textBeforeCursor);
    if (mentionMatch != null) {
      final query = mentionMatch.group(1) ?? '';
      setState(() => _showHashtagSuggestions = false);
      _mentionDebounce = Timer(const Duration(milliseconds: 250), () {
        _searchMentions(query);
      });
      return;
    }

    setState(() {
      _showMentionSuggestions = false;
      _mentionSuggestions.clear();
    });

    final hashtagMatch = RegExp(r'#(\w*)$').firstMatch(textBeforeCursor);
    if (hashtagMatch != null) {
      final query = hashtagMatch.group(1) ?? '';
      _hashtagDebounce = Timer(const Duration(milliseconds: 300), () {
        _searchHashtags(query);
      });
    } else {
      setState(() {
        _showHashtagSuggestions = false;
        _hashtagSuggestions.clear();
      });
    }
  }

  Future<void> _searchMentions(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _showMentionSuggestions = false);
      return;
    }
    try {
      final res = await dioClient.get(
          '/v1/user/mention-search?q=${Uri.encodeComponent(query)}&limit=4');
      if (res.data != null &&
          res.data['success'] == true &&
          res.data['users'] != null &&
          mounted) {
        final list = (res.data['users'] as List)
            .where((u) => u['id'] != _userProfile?['id'])
            .toList();
        setState(() {
          _mentionSuggestions = list;
          _showMentionSuggestions = list.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  Future<void> _searchHashtags(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _showHashtagSuggestions = false);
      return;
    }
    try {
      final res = await dioClient.get(
          '/v1/hashtags/search?q=${Uri.encodeComponent(query)}&limit=12');
      if (res.data != null &&
          res.data['success'] == true &&
          res.data['data']?['hashtags'] != null &&
          mounted) {
        final list = res.data['data']['hashtags'] as List;
        setState(() {
          _hashtagSuggestions = list;
          _showHashtagSuggestions = list.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  void _insertMention(Map<String, dynamic> user) {
    final text = _contentCtrl.text;
    final pos = _cursorPosition.clamp(0, text.length);
    final matchStart = text.substring(0, pos).lastIndexOf('@');
    if (matchStart == -1) return;
    final String username = (user['username'] ?? '').toString();
    final newText =
        '${text.substring(0, matchStart)}@$username ${text.substring(pos)}';
    _contentCtrl.text = newText;
    final newPos = matchStart + username.length + 2;
    _contentCtrl.selection = TextSelection.collapsed(offset: newPos);
    _cursorPosition = newPos;
    setState(() {
      _showMentionSuggestions = false;
      _mentionSuggestions.clear();
    });
  }

  void _insertHashtag(String tag) {
    final text = _contentCtrl.text;
    final pos = _cursorPosition.clamp(0, text.length);
    final matchStart = text.substring(0, pos).lastIndexOf('#');
    if (matchStart == -1) return;
    final newText =
        '${text.substring(0, matchStart)}#$tag ${text.substring(pos)}';
    _contentCtrl.text = newText;
    final newPos = matchStart + tag.length + 2;
    _contentCtrl.selection = TextSelection.collapsed(offset: newPos);
    _cursorPosition = newPos;
    setState(() {
      _showHashtagSuggestions = false;
      _hashtagSuggestions.clear();
    });
  }

  void _insertAtCursor(String insertion) {
    final text = _contentCtrl.text;
    final pos = _cursorPosition.clamp(0, text.length);
    final before = text.substring(0, pos);
    final after = text.substring(pos);
    final needsSpace = before.isNotEmpty && !before.endsWith(' ');
    final newText =
        before + (needsSpace ? ' $insertion' : insertion) + after;
    _contentCtrl.text = newText;
    final newPos =
        pos + (needsSpace ? insertion.length + 1 : insertion.length);
    _contentCtrl.selection = TextSelection.collapsed(offset: newPos);
    _cursorPosition = newPos;
    _contentFocusNode.requestFocus();
  }

  // ── Media ─────────────────────────────────────────────────────────────────────

  Future<void> _initVideoPreviewPlayer(File videoFile) async {
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(videoFile)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _videoDuration = _videoPlayerController!.value.duration;
          });
          _videoPlayerController!.setLooping(true);
        }
      });

    _videoPlayerController?.addListener(() {
      if (mounted && _videoPlayerController != null) {
        setState(() {
          _videoPosition = _videoPlayerController!.value.position;
          _isVideoPlaying = _videoPlayerController!.value.isPlaying;
        });
      }
    });
  }

  String _normalizeAspectRatio(int width, int height) {
    if (width <= 0 || height <= 0) return '1:1';
    final ratio = width / height;
    const tolerance = 0.1;
    if ((ratio - 1.0).abs() <= tolerance) return '1:1';
    if ((ratio - 16 / 9).abs() <= tolerance) return '16:9';
    if ((ratio - 9 / 16).abs() <= tolerance) return '9:16';
    const ratios = [
      (name: '1:1', value: 1.0),
      (name: '16:9', value: 16 / 9),
      (name: '9:16', value: 9 / 16),
    ];
    var closest = ratios[0];
    var minDiff = (ratio - closest.value).abs();
    for (final r in ratios) {
      final diff = (ratio - r.value).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = r;
      }
    }
    return closest.name;
  }

  // ── Validation ────────────────────────────────────────────────────────────────

  bool _validatePost() {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      _showAlert(
        title: 'Content Required',
        message:
            'Please write something before posting. Text content is mandatory.',
        type: 'info',
      );
      return false;
    }
    if (_selectedVideo != null && _selectedImages.isNotEmpty) {
      _showAlert(
        title: 'Mixed Media',
        message: 'Posts cannot have both images and video.',
        type: 'info',
      );
      return false;
    }
    return true;
  }

  Future<bool> _checkUploadLimit() async {
    if (_uid == null) return true;
    try {
      final res = await dioClient.get('/v1/config/upload-limit/$_uid');
      if (res.data != null && res.data['can_upload'] == false) {
        _showAlert(
          title: 'Upload Limit Reached',
          message:
              'You have reached your daily upload limit of ${res.data['daily_limit']} posts.',
          type: 'danger',
        );
        return false;
      }
    } catch (_) {}
    return true;
  }

  // ── Share / Submit ────────────────────────────────────────────────────────────

  Future<void> _handleShare() async {
    if (_isSubmitting || _uploading) return;
    _isSubmitting = true;

    try {
      if (_userProfile?['access']?['can_post'] == false) {
        _showAlert(
          title: 'Server Error',
          message: 'Something went wrong on our end. Please try again later.',
          type: 'danger',
        );
        return;
      }

      if (!_validatePost()) return;
      if (!(await _checkUploadLimit())) return;

      final postContent = _contentCtrl.text.trim();
      final images = List<File>.from(_selectedImages);
      final imagesMeta =
          List<Map<String, dynamic>>.from(_selectedImagesMeta);
      final video = _selectedVideo;
      final videoW = _selectedVideoWidth;
      final videoH = _selectedVideoHeight;
      final videoDur = _selectedVideoDuration;
      final location = _userLocation;

      if (widget.isEditing && widget.postId != null) {
        setState(() => _uploading = true);
        try {
          final res = await dioClient.put('/v1/posts/${widget.postId}', data: {
            'userId': _uid,
            'content': postContent,
          });
          if (res.data != null && res.data['success'] == true) {
            if (mounted) context.pop(true);
          } else {
            throw Exception(res.data?['message'] ?? 'Failed to update post');
          }
        } catch (e) {
          _showAlert(
            title: 'Error',
            message: 'Failed to update post: $e',
            type: 'danger',
          );
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
        return;
      }

      if (!mounted) return;
      context.pop(true);

      _performBackgroundUpload(
        content: postContent,
        images: images,
        imagesMeta: imagesMeta,
        video: video,
        videoWidth: videoW,
        videoHeight: videoH,
        videoDuration: videoDur,
        location: location,
      );
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> _performBackgroundUpload({
    required String content,
    required List<File> images,
    required List<Map<String, dynamic>> imagesMeta,
    required File? video,
    required int? videoWidth,
    required int? videoHeight,
    required int videoDuration,
    required CachedLocation? location,
  }) async {
    final progressNotifier = ref.read(globalUploadProgressProvider.notifier);
    final uploadText =
        video != null ? 'Sharing to Mini...' : 'Sharing to Post...';

    progressNotifier.show(
      text: uploadText,
      icon: 'cloud-upload',
      showProgressBar: true,
      progress: 10.0,
    );

    try {
      if (_uid == null || _uid!.isEmpty) {
        progressNotifier.update(
          text: 'User not authenticated',
          icon: 'error',
          backgroundColor: Colors.red.shade700,
          showProgressBar: false,
          showDismiss: true,
        );
        return;
      }

      final List<Map<String, dynamic>> mediaData = [];

      if (video != null) {
        final videoFileName =
            'video-$_uid-${DateTime.now().millisecondsSinceEpoch}.mp4';
        final uploaded = await uploadService.uploadVideoChunked(
          file: video,
          fileName: videoFileName,
          userId: _uid ?? '',
          onProgress: (percent) {
            progressNotifier.update(progress: 10.0 + (percent * 0.7));
          },
        );

        final thumbRaw = uploaded['thumbnail'];
        final thumbUrl = (thumbRaw is Map) ? thumbRaw['url'] : thumbRaw;

        mediaData.add({
          'type': 'video',
          'url': uploaded['url'],
          'aspectRatio': _normalizeAspectRatio(
            videoWidth ?? 0,
            videoHeight ?? 0,
          ),
          'width': videoWidth,
          'height': videoHeight,
          'duration': videoDuration,
          'thumbnail': thumbUrl,
        });
      } else if (images.isNotEmpty) {
        final total = images.length;
        for (int i = 0; i < total; i++) {
          final imgFile = images[i];
          final meta =
              imagesMeta.length > i ? imagesMeta[i] : <String, dynamic>{};
          final imgFileName =
              'image-$_uid-${DateTime.now().millisecondsSinceEpoch}-$i.jpg';

          final uploaded = await uploadService.uploadMedia(
            file: imgFile,
            mediaType: 'image',
            fileName: imgFileName,
            userId: _uid ?? '',
            onProgress: (percent) {
              final scaled =
                  20.0 + ((i + (percent / 100.0)) / total * 60.0);
              progressNotifier.update(progress: scaled);
            },
          );

          final w = (meta['width'] as int?) ?? 0;
          final h = (meta['height'] as int?) ?? 0;

          mediaData.add({
            'type': 'image',
            'url': uploaded['url'],
            'thumbnail': uploaded['thumbnail'],
            'aspectRatio': _normalizeAspectRatio(w, h),
            'width': w > 0 ? w : null,
            'height': h > 0 ? h : null,
          });
        }
      }

      progressNotifier.update(text: 'Finalizing post...', progress: 90.0);

      String appVersion = '';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = info.buildNumber;
      } catch (_) {}

      final payload = {
        'user_id': _uid,
        'content': content.isNotEmpty ? content : null,
        'media': mediaData.isNotEmpty ? mediaData : null,
        if (location != null)
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'city': location.city,
            'country': location.country,
          },
      };

      final response = await dioClient.post(
        '/v1/posts${appVersion.isNotEmpty ? '?app_version=$appVersion' : ''}',
        data: payload,
      );

      if (response.data != null && response.data['success'] == true) {
        await Analytics.logPostCreated(video != null ? 'mini' : 'moment');

        progressNotifier.update(
          text: video != null
              ? 'Your mini has been shared'
              : 'Your post has been shared',
          icon: 'check-circle',
          backgroundColor: const Color(0xFF4CAF50),
          showProgressBar: false,
          progress: 100.0,
          showDismiss: true,
        );

        Future.delayed(const Duration(seconds: 3), () {
          progressNotifier.hide();
        });
      } else {
        throw Exception(
            response.data?['message'] ?? 'Failed to create post');
      }
    } catch (e) {
      String errorMsg;
      if (e is DioException) {
        final data = e.response?.data;
        errorMsg =
            (data is Map ? data['message'] ?? data['error'] : null)
                    ?.toString() ??
                e.message ??
                'Failed to create post. Please try again.';
      } else {
        errorMsg = e.toString().replaceFirst('Exception: ', '');
      }
      progressNotifier.update(
        text: errorMsg,
        icon: 'error',
        backgroundColor: Colors.red.shade700,
        showProgressBar: false,
        showDismiss: true,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatCount(dynamic count) {
    if (count == null) return '0';
    final n = count is int ? count : int.tryParse(count.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _userProfile?['name'] ?? '';
    final username = _userProfile?['username'] ?? '';
    final pic = _userProfile?['profile_pic'];
    final isVerified = _userProfile?['is_verified'] == true;
    final badgeColor = _userProfile?['verification_badge']?['color'];

    return PopScope(
      canPop: !_uploading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _uploading) {
          _showAlert(
            title: 'Upload in Progress',
            message: 'Please wait for the update to finish.',
            type: 'info',
          );
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildAppBar(theme),
        body: Stack(
          children: [
            _buildScrollBody(theme, name, username, pic, isVerified, badgeColor),
            if (_showVideoPreviewModal && _selectedVideo != null)
              _buildVideoPreviewModal(),
            CustomAlertDialog(
              visible: _alertVisible,
              title: _alertTitle,
              message: _alertMessage,
              type: _alertType,
              buttons: _alertButtons,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    final borderColor = theme.dividerTheme.color ?? AppColors.border;
    final textColor =
        theme.textTheme.bodyLarge?.color ?? AppColors.text;
    final primaryColor = theme.colorScheme.primary;

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      surfaceTintColor: const Color(0x00000000),
      leading: GestureDetector(
        onTap: () {
          if (_uploading) {
            _showAlert(
              title: 'Upload in Progress',
              message: 'Please wait for the update to finish.',
              type: 'info',
            );
          } else {
            context.pop();
          }
        },
        child: Container(
          alignment: Alignment.center,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
        ),
      ),
      title: Text(
        widget.isEditing ? 'Edit Post' : 'New Post',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          child: GestureDetector(
            onTap: _uploading ? null : _handleShare,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              decoration: BoxDecoration(
                color: _uploading
                    ? primaryColor.withValues(alpha: 0.45)
                    : primaryColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_uploading) ...[
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.isEditing ? 'Update' : 'Post',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(
          height: 0.5,
          color: borderColor,
        ),
      ),
    );
  }

  Widget _buildScrollBody(
    ThemeData theme,
    String name,
    String username,
    String? pic,
    bool isVerified,
    dynamic badgeColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildUserInfoSection(theme, name, username, pic, isVerified, badgeColor),
          const SizedBox(height: 16),
          _buildPostComposer(theme),
          if (!widget.isEditing) ...[
            const SizedBox(height: 8),
            _buildDivider(theme),
            const SizedBox(height: 16),
            _buildActionButtons(theme),
            if (_popularHashtags.isNotEmpty && !_showHashtagSuggestions) ...[
              const SizedBox(height: 24),
              _buildTrendingHashtags(theme),
            ],
            if (_showHashtagSuggestions && _hashtagSuggestions.isNotEmpty)
              _buildHashtagSuggestions(theme),
            if (_showMentionSuggestions && _mentionSuggestions.isNotEmpty)
              _buildMentionSuggestions(theme),
            if (_selectedVideo != null) ...[
              const SizedBox(height: 16),
              _buildVideoPreviewThumbnail(theme),
            ],
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPhotoGrid(theme),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(
    ThemeData theme,
    String name,
    String username,
    String? pic,
    bool isVerified,
    dynamic badgeColor,
  ) {
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.text;
    final textTerColor =
        theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final surfaceColor =
        theme.inputDecorationTheme.fillColor ?? AppColors.cardBackground;
    final borderColor = theme.dividerTheme.color ?? AppColors.border;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(
            name: name,
            pic: pic,
            isVerified: isVerified,
            badgeColor: badgeColor,
            primaryColor: primaryColor,
            bgColor: theme.scaffoldBackgroundColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Loading...',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: textColor,
                  ),
                ),
                if (username.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    '@$username',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textTerColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _VisibilityChip(
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textColor: textColor,
            textTerColor: textTerColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String name,
    required String? pic,
    required bool isVerified,
    required dynamic badgeColor,
    required Color primaryColor,
    required Color bgColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: AppColors.primaryButton,
          backgroundImage:
              pic != null ? CachedNetworkImageProvider(pic) : null,
          child: pic == null
              ? Text(
                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    fontSize: 17,
                  ),
                )
              : null,
        ),
        if (isVerified)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
              ),
              child: Icon(
                Icons.verified,
                size: 14,
                color: badgeColor != null
                    ? Color(int.parse(
                        badgeColor.replaceFirst('#', '0xFF')))
                    : primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostComposer(ThemeData theme) {
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.text;
    final hintColor =
        theme.inputDecorationTheme.hintStyle?.color ?? AppColors.placeholder;
    final len = _contentCtrl.text.length;
    final ratio = len / _maxCharacterCount;
    final counterColor = ratio >= 0.9
        ? AppColors.error
        : ratio >= 0.7
            ? AppColors.warning
            : (theme.textTheme.bodySmall?.color ?? AppColors.textTertiary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _contentCtrl,
            focusNode: _contentFocusNode,
            style: TextStyle(
              color: textColor,
              fontFamily: 'Outfit',
              fontSize: 17,
              height: 1.6,
              letterSpacing: 0.1,
            ),
            maxLines: null,
            minLines: 6,
            maxLength: _maxCharacterCount,
            onChanged: _onContentChanged,
            onTap: () {
              if (_contentCtrl.selection.isValid) {
                setState(() {
                  _cursorPosition =
                      _contentCtrl.selection.baseOffset;
                });
              }
            },
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: TextStyle(
                color: hintColor,
                fontFamily: 'Outfit',
                fontSize: 17,
                height: 1.6,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$len / $_maxCharacterCount',
              style: TextStyle(
                color: counterColor,
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    final borderColor = theme.dividerTheme.color ?? AppColors.border;
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: borderColor,
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final borderColor = theme.dividerTheme.color ?? AppColors.border;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _PostActionButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Tag People',
              color: primaryColor,
              borderColor: borderColor,
              onTap: () => _insertAtCursor('@'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PostActionButton(
              icon: Icons.tag_rounded,
              label: 'Add Hashtag',
              color: primaryColor,
              borderColor: borderColor,
              onTap: () => _insertAtCursor('#'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingHashtags(ThemeData theme) {
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.text;
    final surfaceColor =
        theme.inputDecorationTheme.fillColor ?? AppColors.cardBackground;
    final borderColor = theme.dividerTheme.color ?? AppColors.border;
    final textTerColor =
        theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final primaryColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: Text(
            'Trending',
            style: theme.textTheme.bodySmall?.copyWith(
              color: textTerColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _popularHashtags.length,
            itemBuilder: (_, i) {
              final item = _popularHashtags[i];
              final tag = item is Map
                  ? item['hashtag'] as String
                  : item.toString();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _TrendingHashtagChip(
                  tag: tag,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  primaryColor: primaryColor,
                  onTap: () => _insertHashtag(tag),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHashtagSuggestions(ThemeData theme) {
    final surfaceColor =
        theme.inputDecorationTheme.fillColor ?? AppColors.cardBackground;
    final borderColor = theme.dividerTheme.color ?? AppColors.border;
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.text;
    final textTerColor =
        theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final primaryColor = theme.colorScheme.primary;

    return _SuggestionContainer(
      surfaceColor: surfaceColor,
      borderColor: borderColor,
      children: _hashtagSuggestions.map((h) {
        final tag = h['hashtag'] ?? '';
        final count = h['usage_count'] ?? 0;
        return _SuggestionTile(
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tag_rounded, size: 16, color: primaryColor),
          ),
          title: '#$tag',
          subtitle: '${_formatCount(count)} public posts',
          textColor: textColor,
          subtitleColor: textTerColor,
          onTap: () => _insertHashtag(tag),
        );
      }).toList(),
    );
  }

  Widget _buildMentionSuggestions(ThemeData theme) {
    final surfaceColor =
        theme.inputDecorationTheme.fillColor ?? AppColors.cardBackground;
    final borderColor = theme.dividerTheme.color ?? AppColors.border;
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.text;
    final textTerColor =
        theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;

    return _SuggestionContainer(
      surfaceColor: surfaceColor,
      borderColor: borderColor,
      children: _mentionSuggestions.map((u) {
        final uMap = u as Map<String, dynamic>;
        final uPic = uMap['profile_pic'] as String?;
        final uName = uMap['name'] ?? '';
        return _SuggestionTile(
          leading: CircleAvatar(
            radius: 17,
            backgroundImage:
                uPic != null ? CachedNetworkImageProvider(uPic) : null,
            backgroundColor: AppColors.primaryButton,
            child: uPic == null
                ? Text(
                    (uName.isNotEmpty ? uName[0] : '?').toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontFamily: 'Outfit',
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          title: uName,
          subtitle: '@${uMap['username'] ?? ''}',
          textColor: textColor,
          subtitleColor: textTerColor,
          onTap: () => _insertMention(uMap),
        );
      }).toList(),
    );
  }

  Widget _buildVideoPreviewThumbnail(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          setState(() => _showVideoPreviewModal = true);
          _videoPlayerController?.play();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                height: 220,
                width: double.infinity,
                color: const Color(0xFF0D0D0D),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0x8AFFFFFF),
                    size: 56,
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xB3000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_rounded,
                          color: Color(0xFFFFFFFF), size: 13),
                      const SizedBox(width: 5),
                      Text(
                        _formatTime(_selectedVideoDuration),
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedVideo = null;
                    _videoPlayerController?.dispose();
                    _videoPlayerController = null;
                  }),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xB3000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFFFFFFF),
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(ThemeData theme) {
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.text;
    final textTerColor =
        theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final primaryColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: Row(
            children: [
              Text(
                '${_selectedImages.length} ${_selectedImages.length > 1 ? 'Photos' : 'Photo'}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Icon(Icons.swap_horiz_rounded,
                  size: 14, color: textTerColor),
              const SizedBox(width: 4),
              Text(
                'Hold & drag to reorder',
                style: TextStyle(
                  color: textTerColor,
                  fontFamily: 'Outfit',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            buildDefaultDragHandles: false,
            itemCount: _selectedImages.length,
            onReorderItem: (oldIdx, newIdx) {
              if (oldIdx >= _selectedImages.length ||
                  newIdx >= _selectedImages.length) {
                return;
              }
              setState(() {
                final img = _selectedImages.removeAt(oldIdx);
                _selectedImages.insert(newIdx, img);
                if (_selectedImagesMeta.length > oldIdx) {
                  final meta = _selectedImagesMeta.removeAt(oldIdx);
                  if (_selectedImagesMeta.length >= newIdx) {
                    _selectedImagesMeta.insert(newIdx, meta);
                  }
                }
              });
            },
            itemBuilder: (_, index) {
              final file = _selectedImages[index];
              return ReorderableDragStartListener(
                key: ValueKey('img-$index-${file.path}'),
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _ImageTile(
                    file: file,
                    index: index,
                    primaryColor: primaryColor,
                    onRemove: () {
                      setState(() {
                        _selectedImages.removeAt(index);
                        if (_selectedImagesMeta.length > index) {
                          _selectedImagesMeta.removeAt(index);
                        }
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreviewModal() {
    return Container(
      color: const Color(0xFF000000),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Text(
                    'Video Preview',
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFFFFFFFF), size: 22),
                    onPressed: () {
                      _videoPlayerController?.pause();
                      setState(() => _showVideoPreviewModal = false);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _videoPlayerController != null &&
                        _videoPlayerController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio:
                            _videoPlayerController!.value.aspectRatio,
                        child: VideoPlayer(_videoPlayerController!),
                      )
                    : const CircularProgressIndicator(
                        color: Color(0xFFFFFFFF)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isVideoPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: const Color(0xFFFFFFFF),
                      size: 40,
                    ),
                    onPressed: () {
                      if (_isVideoPlaying) {
                        _videoPlayerController?.pause();
                      } else {
                        _videoPlayerController?.play();
                      }
                    },
                  ),
                  Expanded(
                    child: Slider(
                      value: _videoPosition.inSeconds
                          .toDouble()
                          .clamp(
                            0.0,
                            _videoDuration.inSeconds.toDouble() > 0
                                ? _videoDuration.inSeconds.toDouble()
                                : 1.0,
                          ),
                      max: _videoDuration.inSeconds > 0
                          ? _videoDuration.inSeconds.toDouble()
                          : 1.0,
                      activeColor: AppColors.primaryButton,
                      inactiveColor: const Color(0x4DFFFFFF),
                      onChanged: (val) {
                        _videoPlayerController?.seekTo(
                            Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                  Text(
                    '${_formatTime(_videoPosition.inSeconds)} / ${_formatTime(_videoDuration.inSeconds)}',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontFamily: 'Outfit',
                      fontSize: 12,
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
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _VisibilityChip extends StatelessWidget {
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final Color textTerColor;

  const _VisibilityChip({
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.textTerColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public_rounded, size: 13, color: textColor),
            const SizedBox(width: 5),
            Text(
              'Everyone',
              style: TextStyle(
                color: textColor,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: textTerColor),
          ],
        ),
      ),
    );
  }
}

class _PostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;

  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0x00000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingHashtagChip extends StatelessWidget {
  final String tag;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final Color primaryColor;
  final VoidCallback onTap;

  const _TrendingHashtagChip({
    required this.tag,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag_rounded, size: 12, color: primaryColor),
            const SizedBox(width: 3),
            Text(
              tag,
              style: TextStyle(
                color: textColor,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionContainer extends StatelessWidget {
  final List<Widget> children;
  final Color surfaceColor;
  final Color borderColor;

  const _SuggestionContainer({
    required this.children,
    required this.surfaceColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: SingleChildScrollView(
        child: Column(children: children),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontFamily: 'Outfit',
                      fontSize: 12,
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
}

class _ImageTile extends StatelessWidget {
  final File file;
  final int index;
  final Color primaryColor;
  final VoidCallback onRemove;

  const _ImageTile({
    required this.file,
    required this.index,
    required this.primaryColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            file,
            width: 128,
            height: 128,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14)),
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0x8A000000),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xB3000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFFFFFFF),
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
