import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';
import '../../services/location_service.dart';
import '../../services/upload_service.dart';
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
  File? _selectedVideo;
  int _selectedVideoDuration = 0; // in seconds

  // Video Preview Modal Player
  VideoPlayerController? _videoPlayerController;
  bool _showVideoPreviewModal = false;
  bool _isVideoPlaying = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

  // States
  bool _uploading = false;
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

  void _showAlert({
    required String title,
    required String message,
    String type = 'info',
    List<DialogButtonConfig>? buttons,
  }) {
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
          _selectedImages.clear();
        });
        _initVideoPreviewPlayer(file);
        break; // Only 1 video allowed
      } else if (type == 'image') {
        if (_selectedImages.length < _maxImages) {
          setState(() {
            _selectedImages.add(file);
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

  void _onContentChanged(String text) {
    _hashtagDebounce?.cancel();
    _mentionDebounce?.cancel();

    final textBeforeCursor = text.substring(0, _cursorPosition.clamp(0, text.length));

    // Check @mention
    final mentionMatch = RegExp(r'@([a-zA-Z0-9_\.]*)$').firstMatch(textBeforeCursor);
    if (mentionMatch != null) {
      final query = mentionMatch.group(1) ?? '';
      setState(() {
        _showHashtagSuggestions = false;
      });
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
      final res = await dioClient.get('/v1/user/mention-search?q=${Uri.encodeComponent(query)}&limit=4');
      if (res.data != null && res.data['success'] == true && res.data['users'] != null && mounted) {
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
      final res = await dioClient.get('/v1/hashtags/search?q=${Uri.encodeComponent(query)}&limit=12');
      if (res.data != null && res.data['success'] == true && res.data['data']?['hashtags'] != null && mounted) {
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
    final textBefore = text.substring(0, _cursorPosition.clamp(0, text.length));
    final textAfter = text.substring(_cursorPosition.clamp(0, text.length));

    final matchStart = textBefore.lastIndexOf('@');
    if (matchStart != -1) {
      final String username = (user['username'] ?? '').toString();
      final newText = '${text.substring(0, matchStart)}@$username $textAfter';
      _contentCtrl.text = newText;
      final int newPos = matchStart + username.length + 2;
      _contentCtrl.selection = TextSelection.collapsed(offset: newPos);
      setState(() {
        _showMentionSuggestions = false;
        _mentionSuggestions.clear();
      });
    }
  }

  void _insertHashtag(String tag) {
    final text = _contentCtrl.text;
    final textBefore = text.substring(0, _cursorPosition.clamp(0, text.length));
    final textAfter = text.substring(_cursorPosition.clamp(0, text.length));

    final matchStart = textBefore.lastIndexOf('#');
    if (matchStart != -1) {
      final newText = '${text.substring(0, matchStart)}#$tag $textAfter';
      _contentCtrl.text = newText;
      final newPos = matchStart + tag.length + 2;
      _contentCtrl.selection = TextSelection.collapsed(offset: newPos);
      setState(() {
        _showHashtagSuggestions = false;
        _hashtagSuggestions.clear();
      });
    }
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _selectedImages.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);

    if (picked.isNotEmpty && mounted) {
      setState(() {
        _selectedImages.addAll(picked.take(remaining).map((x) => File(x.path)));
        _selectedVideo = null;
      });
    }
  }

  Future<void> _initVideoPreviewPlayer(File videoFile) async {
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(videoFile)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _videoDuration = _videoPlayerController!.value.duration;
          });
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

  bool _validatePost() {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      _showAlert(
        title: 'Content Required',
        message: 'Please write something before posting.',
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
          message: 'You have reached your daily upload limit of ${res.data['daily_limit']} posts.',
          type: 'danger',
        );
        return false;
      }
    } catch (_) {}
    return true;
  }

  Future<void> _handleShare() async {
    if (_uploading) return;
    if (!_validatePost()) return;
    if (!(await _checkUploadLimit())) return;

    final postContent = _contentCtrl.text.trim();
    final images = List<File>.from(_selectedImages);
    final video = _selectedVideo;
    final location = _userLocation;

    if (widget.isEditing && widget.postId != null) {
      // Edit post
      setState(() => _uploading = true);
      try {
        await dioClient.put('/v1/posts/${widget.postId}', data: {
          'userId': _uid,
          'content': postContent,
        });
        if (mounted) context.pop(true);
      } catch (e) {
        _showAlert(title: 'Error', message: 'Failed to update post: $e', type: 'danger');
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
      return;
    }

    // New post background upload
    if (!mounted) return;
    context.pop(true);

    // Trigger background process
    _performBackgroundUpload(
      content: postContent,
      images: images,
      video: video,
      location: location,
    );
  }

  Future<void> _performBackgroundUpload({
    required String content,
    required List<File> images,
    required File? video,
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
      final List<Map<String, dynamic>> mediaData = [];

      if (video != null) {
        final videoFileName = 'video-$_uid-${DateTime.now().millisecondsSinceEpoch}.mp4';
        final uploaded = await uploadService.uploadVideoChunked(
          file: video,
          fileName: videoFileName,
          userId: _uid ?? '',
          onProgress: (percent) {
            progressNotifier.update(progress: 10.0 + (percent * 0.7));
          },
        );

        mediaData.add({
          'type': 'video',
          'url': uploaded['url'],
          'aspectRatio': '16:9',
          'thumbnail': uploaded['thumbnail']?['url'] ?? uploaded['thumbnail'],
        });
      } else if (images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final imgFile = images[i];
          final imgFileName = 'image-$_uid-${DateTime.now().millisecondsSinceEpoch}-$i.jpg';

          final uploaded = await uploadService.uploadMedia(
            file: imgFile,
            mediaType: 'image',
            fileName: imgFileName,
            userId: _uid ?? '',
            onProgress: (percent) {
              final scaled = 20.0 + ((i + (percent / 100.0)) / images.length * 60.0);
              progressNotifier.update(progress: scaled);
            },
          );

          mediaData.add({
            'type': 'image',
            'url': uploaded['url'],
            'thumbnail': uploaded['thumbnail'],
            'aspectRatio': '1:1',
          });
        }
      }

      progressNotifier.update(text: 'Finalizing post...', progress: 90.0);

      final payload = {
        'user_id': _uid,
        'content': content,
        'media': mediaData.isNotEmpty ? mediaData : null,
        if (location != null)
          'location': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'city': location.city,
            'country': location.country,
          },
      };

      final response = await dioClient.post('/v1/posts', data: payload);

      if (response.data != null && response.data['success'] == true) {
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
      progressNotifier.update(
        text: 'Failed to share post: $e',
        icon: 'error',
        backgroundColor: Colors.red.shade700,
        showProgressBar: false,
        showDismiss: true,
      );
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final name = _userProfile?['name'] ?? '';
    final username = _userProfile?['username'] ?? '';
    final pic = _userProfile?['profile_pic'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              widget.isEditing ? 'Edit Post' : 'Create Post',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            const Text(
              'Share with your community',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Outfit',
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              ),
              onPressed: _uploading ? null : _handleShare,
              icon: _uploading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 14, color: Colors.white),
              label: Text(
                widget.isEditing ? 'Update' : 'Share',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── User Info Row ──
                if (_userProfile != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: AppColors.border,
                          backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                          child: pic == null
                              ? Text(
                                  (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '@$username',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontFamily: 'Outfit',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const Divider(color: AppColors.border, height: 1),

                // ── Content Text Input Section ──
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: _contentCtrl,
                        focusNode: _contentFocusNode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          height: 1.4,
                        ),
                        maxLines: null,
                        maxLength: _maxCharacterCount,
                        onChanged: _onContentChanged,
                        onTap: () {
                          setState(() {
                            _cursorPosition = _contentCtrl.selection.baseOffset;
                          });
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
                        ),
                      ),
                      Text(
                        '${_contentCtrl.text.length}/$_maxCharacterCount',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontFamily: 'Outfit',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tag People / Hashtag Chips ──
                if (!widget.isEditing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final text = _contentCtrl.text;
                            _contentCtrl.text = '$text @';
                            _contentCtrl.selection = TextSelection.collapsed(
                              offset: _contentCtrl.text.length,
                            );
                            _contentFocusNode.requestFocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.alternate_email, size: 15, color: Color(0xFF6366F1)),
                                SizedBox(width: 4),
                                Text(
                                  'Tag People',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final text = _contentCtrl.text;
                            _contentCtrl.text = '$text #';
                            _contentCtrl.selection = TextSelection.collapsed(
                              offset: _contentCtrl.text.length,
                            );
                            _contentFocusNode.requestFocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.tag, size: 15, color: Color(0xFFEC4899)),
                                SizedBox(width: 4),
                                Text(
                                  'Hashtag',
                                  style: TextStyle(
                                    color: Color(0xFFEC4899),
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Popular Hashtags Section ──
                if (!widget.isEditing && _popularHashtags.isNotEmpty && !_showHashtagSuggestions) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 12, bottom: 6),
                    child: Text(
                      'POPULAR',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _popularHashtags.length,
                      itemBuilder: (_, index) {
                        final item = _popularHashtags[index];
                        final tag = item is Map ? item['hashtag'] : item.toString();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            backgroundColor: AppColors.cardBackground,
                            side: const BorderSide(color: AppColors.border),
                            label: Text(
                              '#$tag',
                              style: const TextStyle(
                                color: AppColors.primaryButton,
                                fontFamily: 'Outfit',
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () => _insertHashtag(tag),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ── Mention Suggestions List ──
                if (_showMentionSuggestions && _mentionSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: _mentionSuggestions.map((u) {
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundImage: u['profile_pic'] != null
                                ? CachedNetworkImageProvider(u['profile_pic'])
                                : null,
                            child: u['profile_pic'] == null
                                ? Text((u['name']?[0] ?? '?').toUpperCase())
                                : null,
                          ),
                          title: Text(
                            u['name'] ?? '',
                            style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 14),
                          ),
                          subtitle: Text(
                            '@${u['username'] ?? ''}',
                            style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Outfit', fontSize: 12),
                          ),
                          onTap: () => _insertMention(u),
                        );
                      }).toList(),
                    ),
                  ),

                // ── Hashtag Suggestions List ──
                if (_showHashtagSuggestions && _hashtagSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: _hashtagSuggestions.map((h) {
                        final tag = h['hashtag'] ?? '';
                        final count = h['usage_count'] ?? 0;
                        return ListTile(
                          title: Text(
                            '#$tag',
                            style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontSize: 14),
                          ),
                          subtitle: Text(
                            '$count posts',
                            style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Outfit', fontSize: 12),
                          ),
                          onTap: () => _insertHashtag(tag),
                        );
                      }).toList(),
                    ),
                  ),

                // ── Selected Video Preview Card ──
                if (!widget.isEditing && _selectedVideo != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: GestureDetector(
                      onTap: () => setState(() => _showVideoPreviewModal = true),
                      child: Stack(
                        children: [
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 56),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.videocam, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTime(_selectedVideoDuration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
                              onTap: () => setState(() => _selectedVideo = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Selected Images Grid ──
                if (!widget.isEditing && _selectedImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: Text(
                            '${_selectedImages.length} photo${_selectedImages.length > 1 ? 's' : ''} selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 110,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _selectedImages.length + (_selectedImages.length < _maxImages ? 1 : 0),
                            itemBuilder: (_, index) {
                              if (index == _selectedImages.length) {
                                return GestureDetector(
                                  onTap: _pickImages,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_rounded, color: AppColors.primaryButton, size: 28),
                                        SizedBox(height: 2),
                                        Text(
                                          'Add More',
                                          style: TextStyle(
                                            color: AppColors.primaryButton,
                                            fontFamily: 'Outfit',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final file = _selectedImages[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        file,
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.cover,
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
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedImages.removeAt(index));
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(color: AppColors.border),

                // Media picker tile
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.textTertiary),
                  title: const Text(
                    'Photo/Video',
                    style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Outfit'),
                  ),
                  onTap: _pickImages,
                ),
              ],
            ),
          ),

          // ── Video Preview Modal Player ──
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
                                aspectRatio: _videoPlayerController!.value.aspectRatio,
                                child: VideoPlayer(_videoPlayerController!),
                              )
                            : const CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isVideoPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
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
                              value: _videoPosition.inSeconds.toDouble().clamp(
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
                                _videoPlayerController?.seekTo(Duration(seconds: val.toInt()));
                              },
                            ),
                          ),
                          Text(
                            _formatTime(_videoPosition.inSeconds),
                            style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Custom Alert Dialog ──
          CustomAlertDialog(
            visible: _alertVisible,
            title: _alertTitle,
            message: _alertMessage,
            type: _alertType,
            buttons: _alertButtons,
          ),
        ],
      ),
    );
  }
}
