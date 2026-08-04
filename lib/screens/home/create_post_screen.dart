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

  // Selected Media
  final List<File> _selectedImages = [];
  final List<Map<String, dynamic>> _selectedImagesMeta = []; // {width, height}
  File? _selectedVideo;
  int _selectedVideoDuration = 0; // in seconds
  int? _selectedVideoWidth;
  int? _selectedVideoHeight;

  // Video Preview Modal Player
  VideoPlayerController? _videoPlayerController;
  bool _showVideoPreviewModal = false;
  bool _isVideoPlaying = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

  // States
  bool _uploading = false;
  bool _isSubmitting = false; // double-tap guard
  String? _uid;
  Map<String, dynamic>? _userProfile;
  CachedLocation? _userLocation;

  // Cursor & Mention/Hashtag suggestions
  int _cursorPosition = 0;
  List<dynamic> _popularHashtags = [];
  List<dynamic> _hashtagSuggestions = [];
  bool _showHashtagSuggestions = false;
  Timer? _hashtagDebounce;

  List<dynamic> _mentionSuggestions = [];
  bool _showMentionSuggestions = false;
  Timer? _mentionDebounce;

  // Alert state
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

  // ── Alert helper ─────────────────────────────────────────────────────────────

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

  // ── Init helpers ─────────────────────────────────────────────────────────────

  Future<void> _checkUploadLimitOnInit() async {
    if (_uid == null) {
      final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    if (_uid != null) {
      try {
        final res = await dioClient.get('/v1/user/$_uid');
        if (res.data != null && res.data['data'] != null && mounted) {
          setState(() => _userProfile = res.data['data']);
        }
      } catch (_) {}
    }
  }

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

    // Check @mention
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

    // Check #hashtag
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
    final newText = '${text.substring(0, matchStart)}@$username ${text.substring(pos)}';
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
    final newText = '${text.substring(0, matchStart)}#$tag ${text.substring(pos)}';
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
    final newText = before + (needsSpace ? ' $insertion' : insertion) + after;
    _contentCtrl.text = newText;
    final newPos = pos + (needsSpace ? insertion.length + 1 : insertion.length);
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

  // ── Aspect ratio normalizer (mirrors RN normalizeAspectRatio) ──────────────

  String _normalizeAspectRatio(int width, int height) {
    if (width <= 0 || height <= 0) return '1:1';
    final ratio = width / height;
    const tolerance = 0.1;
    if ((ratio - 1.0).abs() <= tolerance) return '1:1';
    if ((ratio - 16 / 9).abs() <= tolerance) return '16:9';
    if ((ratio - 9 / 16).abs() <= tolerance) return '9:16';
    // Find closest
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
        message: 'Please write something before posting. Text content is mandatory.',
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
      // can_post access guard (mirrors RN can_post check)
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
      final imagesMeta = List<Map<String, dynamic>>.from(_selectedImagesMeta);
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

      // New post: navigate away immediately, upload in background
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
    final uploadText = video != null ? 'Sharing to Mini...' : 'Sharing to Post...';

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
          final meta = imagesMeta.length > i ? imagesMeta[i] : <String, dynamic>{};
          final imgFileName =
              'image-$_uid-${DateTime.now().millisecondsSinceEpoch}-$i.jpg';

          final uploaded = await uploadService.uploadMedia(
            file: imgFile,
            mediaType: 'image',
            fileName: imgFileName,
            userId: _uid ?? '',
            onProgress: (percent) {
              final scaled = 20.0 + ((i + (percent / 100.0)) / total * 60.0);
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

      // Build app version string for the query param
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
        // Analytics
        await Analytics.logPostCreated(video != null ? 'mini' : 'moment');

        progressNotifier.update(
          text: video != null ? 'Your mini has been shared' : 'Your post has been shared',
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
        throw Exception(response.data?['message'] ?? 'Failed to create post');
      }
    } catch (e) {
      String errorMsg;
      if (e is DioException) {
        final data = e.response?.data;
        errorMsg = (data is Map ? data['message'] ?? data['error'] : null)?.toString() ??
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

  Widget _buildCharCounter() {
    final len = _contentCtrl.text.length;
    final ratio = len / _maxCharacterCount;
    Color color;
    if (ratio >= 0.9) {
      color = AppColors.error;
    } else if (ratio >= 0.7) {
      color = AppColors.warning;
    } else {
      color = AppColors.textTertiary;
    }
    return Text(
      '$len / $_maxCharacterCount',
      style: TextStyle(
        color: color,
        fontFamily: 'Outfit',
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
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
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          title: Text(
            widget.isEditing ? 'Edit Post' : 'New Post',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              fontSize: 17,
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
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  decoration: BoxDecoration(
                    color: _uploading
                        ? AppColors.primaryButton.withValues(alpha: 0.4)
                        : AppColors.primaryButton,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_uploading)
                        const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      Text(
                        widget.isEditing ? 'Update' : 'Post',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── User Info Row ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primaryButton,
                              backgroundImage: pic != null
                                  ? CachedNetworkImageProvider(pic)
                                  : null,
                              child: pic == null
                                  ? Text(
                                      (name.isNotEmpty ? name[0] : '?')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17),
                                    )
                                  : null,
                            ),
                            if (isVerified)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.background,
                                  ),
                                  child: Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: badgeColor != null
                                        ? Color(int.parse(
                                            badgeColor.replaceFirst('#', '0xFF')))
                                        : AppColors.primaryButton,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isNotEmpty ? name : 'Loading...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (username.isNotEmpty)
                                Text(
                                  '@$username',
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.public_rounded,
                                    size: 13, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'Everyone',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 16, color: AppColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Content Input ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _contentCtrl,
                            focusNode: _contentFocusNode,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontFamily: 'Outfit',
                              fontSize: 16,
                              height: 1.55,
                              letterSpacing: 0.1,
                            ),
                            maxLines: null,
                            minLines: 5,
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
                            decoration: const InputDecoration(
                              hintText: "What's on your mind?",
                              hintStyle: TextStyle(
                                color: AppColors.placeholder,
                                fontFamily: 'Outfit',
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [_buildCharCounter()],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Tag People / Add Hashtag buttons ──────────────────────
                  if (!widget.isEditing) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionChip(
                              icon: Icons.person_outline_rounded,
                              label: 'Tag People',
                              color: AppColors.primaryButton,
                              onTap: () => _insertAtCursor('@'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionChip(
                              icon: Icons.tag_rounded,
                              label: 'Add Hashtag',
                              color: AppColors.primaryButton,
                              onTap: () => _insertAtCursor('#'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Popular Hashtags ──────────────────────────────────────
                  if (!widget.isEditing &&
                      _popularHashtags.isNotEmpty &&
                      !_showHashtagSuggestions) ...[
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.only(left: 16, right: 16, bottom: 10),
                      child: Text(
                        'Trending Hashtags',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 36,
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
                            child: GestureDetector(
                              onTap: () => _insertHashtag(tag),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  '# $tag',
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Hashtag Suggestions ───────────────────────────────────
                  if (_showHashtagSuggestions && _hashtagSuggestions.isNotEmpty)
                    _SuggestionContainer(
                      children: _hashtagSuggestions.map((h) {
                        final tag = h['hashtag'] ?? '';
                        final count = h['usage_count'] ?? 0;
                        return ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primaryButton.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tag_rounded,
                                size: 16, color: AppColors.primaryButton),
                          ),
                          title: Text(
                            '#$tag',
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_formatCount(count)} public posts',
                            style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontFamily: 'Outfit',
                                fontSize: 12),
                          ),
                          onTap: () => _insertHashtag(tag),
                        );
                      }).toList(),
                    ),

                  // ── Mention Suggestions ───────────────────────────────────
                  if (_showMentionSuggestions && _mentionSuggestions.isNotEmpty)
                    _SuggestionContainer(
                      children: _mentionSuggestions.map((u) {
                        final uMap = u as Map<String, dynamic>;
                        final uPic = uMap['profile_pic'] as String?;
                        final uName = uMap['name'] ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundImage: uPic != null
                                ? CachedNetworkImageProvider(uPic)
                                : null,
                            backgroundColor: AppColors.primaryButton,
                            child: uPic == null
                                ? Text(
                                    (uName.isNotEmpty ? uName[0] : '?')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Outfit',
                                        fontSize: 12),
                                  )
                                : null,
                          ),
                          title: Text(
                            uName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '@${uMap['username'] ?? ''}',
                            style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontFamily: 'Outfit',
                                fontSize: 12),
                          ),
                          onTap: () => _insertMention(uMap),
                        );
                      }).toList(),
                    ),

                  // ── Selected Video Preview ────────────────────────────────
                  if (!widget.isEditing && _selectedVideo != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _showVideoPreviewModal = true);
                          _videoPlayerController?.play();
                        },
                        child: Stack(
                          children: [
                            Container(
                              height: 260,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0D0D),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Center(
                                child: Icon(Icons.play_circle_fill_rounded,
                                    color: Colors.white54, size: 60),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.videocam_rounded,
                                        color: Colors.white, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTime(_selectedVideoDuration),
                                      style: const TextStyle(
                                        color: Colors.white,
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
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedVideo = null;
                                  _videoPlayerController?.dispose();
                                  _videoPlayerController = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Selected Images ───────────────────────────────────────
                  if (!widget.isEditing && _selectedImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 10),
                            child: Row(
                              children: [
                                Text(
                                  '${_selectedImages.length} ${_selectedImages.length > 1 ? 'Photos' : 'Photo'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.drag_indicator_rounded,
                                    size: 15,
                                    color: AppColors.textTertiary),
                                const SizedBox(width: 4),
                                const Text(
                                  'Hold & drag to reorder',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 130,
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
                                    final meta =
                                        _selectedImagesMeta.removeAt(oldIdx);
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
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.file(
                                            file,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      bottom:
                                                          Radius.circular(12)),
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.black
                                                      .withValues(alpha: 0.55),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          left: 6,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primaryButton,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 5,
                                          right: 5,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedImages.removeAt(index);
                                                if (_selectedImagesMeta.length >
                                                    index) {
                                                  _selectedImagesMeta
                                                      .removeAt(index);
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.65),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.close_rounded,
                                                  color: Colors.white,
                                                  size: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Video Preview Modal ──────────────────────────────────────────
            if (_showVideoPreviewModal && _selectedVideo != null)
              Container(
                color: Colors.black,
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Video Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              _videoPlayerController?.pause();
                              setState(() => _showVideoPreviewModal = false);
                            },
                          ),
                        ],
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
                                  color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isVideoPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                color: Colors.white,
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
                                inactiveColor: Colors.white30,
                                onChanged: (val) {
                                  _videoPlayerController?.seekTo(
                                      Duration(seconds: val.toInt()));
                                },
                              ),
                            ),
                            Text(
                              '${_formatTime(_videoPosition.inSeconds)} / ${_formatTime(_videoDuration.inSeconds)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Outfit',
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Custom Alert Dialog ──────────────────────────────────────────
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

  String _formatCount(dynamic count) {
    if (count == null) return '0';
    final n = count is int ? count : int.tryParse(count.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Private helper widgets ───────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
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

class _SuggestionContainer extends StatelessWidget {
  final List<Widget> children;
  const _SuggestionContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Column(children: children),
      ),
    );
  }
}
