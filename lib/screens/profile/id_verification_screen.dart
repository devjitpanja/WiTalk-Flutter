import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../api/dio_client.dart';
import '../../config/app_config.dart';
import '../../services/location_service.dart';

const _maxDurationSeconds = 20;

class IdVerificationScreen extends ConsumerStatefulWidget {
  const IdVerificationScreen({super.key});
  @override
  ConsumerState<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends ConsumerState<IdVerificationScreen>
    with WidgetsBindingObserver {
  static const _secureStorage = FlutterSecureStorage();

  bool _loading = true;
  bool _uploading = false;
  double _uploadProgress = 0;
  XFile? _recordedVideo;
  int? _videoDuration;
  Map<String, dynamic>? _verificationStatus;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _eligibility;
  bool? _locationPermission;
  String? _gpsCity;
  bool _pendingLocationRetry = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingLocationRetry) {
      _pendingLocationRetry = false;
      _checkLocationPermission();
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadVerificationStatus(),
      _loadUserData(),
      _loadEligibility(),
      _checkLocationPermission(),
    ]);
  }

  Future<void> _loadVerificationStatus() async {
    try {
      if (mounted) setState(() => _loading = true);
      final res = await dioClient.get('/v1/verification/status');
      if (mounted) setState(() => _verificationStatus = res.data['data'] as Map<String, dynamic>?);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) return;
      final res = await dioClient.get('/v1/user/$uid');
      if (mounted) setState(() => _userData = res.data['data'] as Map<String, dynamic>?);
    } catch (_) {}
  }

  Future<void> _loadEligibility() async {
    try {
      final res = await dioClient.get('/v1/verification/eligibility');
      if (mounted) setState(() => _eligibility = res.data['data'] as Map<String, dynamic>?);
    } catch (_) {}
  }

  Future<void> _checkLocationPermission() async {
    try {
      final granted = await locationService.checkPermission();
      if (mounted) setState(() => _locationPermission = granted);
      if (granted) {
        locationService.getLocation().then((loc) {
          if (loc.city != null && mounted) setState(() => _gpsCity = loc.city);
        }).catchError((_) {});
      }
    } catch (_) {
      if (mounted) setState(() => _locationPermission = false);
    }
  }

  Future<void> _openLocationSettings() async {
    _pendingLocationRetry = true;
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      _pendingLocationRetry = false;
    }
  }

  Future<bool> _checkAndRequestPermission(Permission permission, String label) async {
    var status = await permission.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      status = await permission.request();
      if (status.isGranted) return true;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      _showAlert(
        'Permission Required',
        '$label permission is permanently denied. Please enable it in your device settings.',
        type: 'danger',
        confirmText: 'Open Settings',
        onConfirm: () async {
          if (mounted) Navigator.of(context).pop();
          await openAppSettings();
        },
      );
      return false;
    }
    return false;
  }

  Future<void> _handleRecordVideo() async {
    if (!_localIsEligible) {
      _showAlert(
        'Not Eligible',
        'You need to meet all requirements before applying for verification.',
        type: 'warning',
      );
      return;
    }
    if (_locationPermission != true) {
      _showAlert(
        'Location Permission Required',
        'Location permission is required for address verification. Please enable it to continue.',
        type: 'warning',
        showCancel: true,
        cancelText: 'Cancel',
        confirmText: 'Open Settings',
        onConfirm: () {
          if (mounted) Navigator.of(context).pop();
          _openLocationSettings();
        },
      );
      return;
    }

    final hasCam = await _checkAndRequestPermission(Permission.camera, 'Camera');
    if (!hasCam) return;
    final hasMic = await _checkAndRequestPermission(Permission.microphone, 'Microphone');
    if (!hasMic) return;

    try {
      final video = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(seconds: _maxDurationSeconds + 5),
      );
      if (video == null || !mounted) return;

      final duration = await _getVideoDuration(video.path);
      if (duration != null && duration > _maxDurationSeconds) {
        if (mounted) {
          _showAlert(
            'Video Too Long',
            'Please record a video shorter than $_maxDurationSeconds seconds. Your video is $duration seconds long.',
            type: 'danger',
          );
        }
        return;
      }

      final sizeMB = (await File(video.path).length()) / (1024 * 1024);
      if (sizeMB > 50) {
        if (mounted) {
          _showAlert('Video Too Large', 'Video file is too large. Please record a shorter video.', type: 'danger');
        }
        return;
      }

      if (mounted) setState(() { _recordedVideo = video; _videoDuration = duration; });
    } catch (e) {
      if (mounted && !e.toString().toLowerCase().contains('cancel')) {
        _showAlert('Error', 'Failed to record video', type: 'danger');
      }
    }
  }

  Future<int?> _getVideoDuration(String path) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      final secs = controller.value.duration.inSeconds;
      await controller.dispose();
      return secs;
    } catch (_) {
      return null;
    }
  }

  Future<String> _uploadVideo(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid') ?? 'unknown';
    final token = await _secureStorage.read(key: 'accessToken');
    final cleanPath = videoPath.replaceFirst('file://', '');
    final fileName = 'verification-video-$uid-${DateTime.now().millisecondsSinceEpoch}.mp4';
    const uploadUrl = '${AppConfig.filesApiBaseUrl}/api/v1/upload/verification-video';

    final uploadDio = Dio();
    final formData = FormData.fromMap({
      'video': await MultipartFile.fromFile(cleanPath, filename: fileName),
      'user_id': uid,
    });

    final response = await uploadDio.post(
      uploadUrl,
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
      onSendProgress: (sent, total) {
        if (mounted && total > 0) setState(() => _uploadProgress = 30 + (sent / total * 40));
      },
    );

    final data = response.data as Map<String, dynamic>?;
    if (response.statusCode == 200 && data?['success'] == true && data?['file'] != null) {
      final url = (data!['file'] as Map?)?['url'] as String?;
      if (url == null) throw Exception('Upload failed: No URL in response');
      return url;
    }
    throw Exception(data?['error'] ?? data?['message'] ?? 'Upload failed');
  }

  Future<void> _handleSubmit() async {
    if (_recordedVideo == null) {
      _showAlert('No Video', 'Please record a verification video first', type: 'info');
      return;
    }
    _showAlert(
      'Submit Verification',
      'Are you sure you want to submit this video for verification? You cannot change it once submitted.',
      type: 'info',
      showCancel: true,
      cancelText: 'Cancel',
      confirmText: 'Submit',
      onConfirm: () {
        if (mounted) Navigator.of(context).pop();
        _performSubmit();
      },
    );
  }

  Future<void> _performSubmit() async {
    try {
      if (mounted) setState(() { _uploading = true; _uploadProgress = 0; });
      if (mounted) setState(() => _uploadProgress = 10);

      final videoUrl = await _uploadVideo(_recordedVideo!.path);
      if (mounted) setState(() => _uploadProgress = 75);

      final response = await dioClient.post('/v1/verification/submit', data: {'videoUrl': videoUrl});
      if (mounted) setState(() => _uploadProgress = 100);

      if (response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Your verification request has been submitted! We'll notify you once it's approved."),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 4),
          ));
          await _loadVerificationStatus();
          setState(() => _recordedVideo = null);
        }
      } else {
        throw Exception(response.data['message'] ?? 'Failed to submit verification');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to submit verification request';
        if (e is DioException) {
          final code = e.response?.statusCode ?? 0;
          if (code == 401) {
            msg = 'Authentication failed. Please try logging in again.';
          } else if (code == 403) {
            msg = 'You do not have permission to submit verification.';
          } else if (code == 400) {
            msg = (e.response?.data?['message'] as String?) ?? 'Invalid verification request. Please check your video and try again.';
          } else if (code >= 500) {
            msg = 'Server error. Please try again later.';
          } else {
            msg = (e.response?.data?['message'] as String?) ?? msg;
          }
        } else {
          msg = e.toString().replaceFirst('Exception: ', '');
        }
        _showAlert('Submission Failed', msg, type: 'danger');
      }
    } finally {
      if (mounted) setState(() { _uploading = false; _uploadProgress = 0; });
    }
  }

  void _showAlert(
    String title,
    String message, {
    String type = 'info',
    bool showCancel = false,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(_alertIcon(type), color: _alertColor(type), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16))),
        ]),
        content: Text(message, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 13, height: 1.5)),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: onCancel ?? () => Navigator.of(ctx).pop(),
              child: Text(cancelText, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          TextButton(
            onPressed: onConfirm ?? () => Navigator.of(ctx).pop(),
            child: Text(confirmText, style: TextStyle(color: _alertColor(type), fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'danger': return AppColors.error;
      case 'warning': return AppColors.warning;
      case 'success': return AppColors.success;
      default: return AppColors.primary;
    }
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'danger': return Icons.error_outline;
      case 'warning': return Icons.warning_amber_outlined;
      case 'success': return Icons.check_circle_outline;
      default: return Icons.info_outline;
    }
  }

  List<dynamic> _parseArray(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is String) {
      try { return jsonDecode(value) as List; } catch (_) { return []; }
    }
    return [];
  }

  int get _localProfileCompletion {
    if (_userData == null) return 0;
    int score = 0;
    if ((_userData!['name'] as String?)?.trim().isNotEmpty == true) score++;
    if ((_userData!['username'] as String?)?.trim().isNotEmpty == true) score++;
    if ((_userData!['bio'] as String?)?.trim().isNotEmpty == true) score++;
    if (_userData!['profile_pic'] != null) score++;
    if (_userData!['gender'] != null) score++;
    if ((_userData!['city'] as String?)?.trim().isNotEmpty == true) score++;
    if (_userData!['occupation'] != null) score++;
    if (_userData!['country'] != null) score++;
    if (_userData!['birthday'] != null) score++;
    if (_parseArray(_userData!['interests']).isNotEmpty) score++;
    if (_parseArray(_userData!['purpose']).isNotEmpty) score++;
    return ((score / 11) * 100).round();
  }

  bool get _localIsEligible => _localProfileCompletion >= 100 && _locationPermission == true;

  int _calculateAge(String? birthday) {
    if (birthday == null) return 0;
    try {
      final dob = DateTime.parse(birthday);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
      return age;
    } catch (_) { return 0; }
  }

  String _getInstructionText() {
    final name = ((_userData?['name'] as String?)?.trim().isNotEmpty == true)
        ? _userData!['name'] as String
        : 'your name';
    final birthday = _userData?['birthday'] as String?;
    final age = birthday != null ? _calculateAge(birthday).toString() : 'your age';
    final city = _gpsCity ?? (_userData?['city'] as String?) ?? 'your city';
    return "Hi, I'm $name, $age years old from $city. I'd like to use WiTalk to [your reason, e.g., meet new people and Make True Friends].";
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 8),
          Text('Loading...', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: colors.textSecondary)),
        ])),
      );
    }

    if (_verificationStatus?['isVerified'] == true) return _buildVerifiedScreen(colors);
    if (_verificationStatus?['pendingRequest']?['status'] == 'pending') return _buildPendingScreen(colors);
    return _buildMainScreen(colors);
  }

  Widget _buildVerifiedScreen(ThemeColors colors) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(child: Column(children: [
        _buildHeader(colors),
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 100, height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF0099FF)]),
            ),
            child: const Icon(Icons.verified, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text("You're Verified!", style: TextStyle(fontSize: 22, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: colors.text)),
          const SizedBox(height: 8),
          Text(
            'Your identity has been verified and you now have a verified badge on your profile.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontFamily: 'Outfit', color: colors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          _gradientButton(
            colors: const [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            onTap: () => context.pop(),
            child: const Text('Done', style: TextStyle(fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ])))),
      ])),
    );
  }

  Widget _buildPendingScreen(ThemeColors colors) {
    final createdAt = _verificationStatus?['pendingRequest']?['createdAt'] as String?;
    String? dateStr;
    if (createdAt != null) {
      try { dateStr = DateTime.parse(createdAt).toLocal().toIso8601String().substring(0, 10); } catch (_) {}
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(child: Column(children: [
        _buildHeader(colors),
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 100, height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFFFA726)]),
            ),
            child: const Icon(Icons.schedule, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text('Verification Pending', style: TextStyle(fontSize: 22, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: colors.text)),
          const SizedBox(height: 8),
          Text(
            "Your verification request is being reviewed by our team. You will receive a notification once it's approved or rejected.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontFamily: 'Outfit', color: colors.textSecondary, height: 1.5),
          ),
          if (dateStr != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time, size: 14, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text('Submitted: $dateStr', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: colors.textSecondary)),
              ]),
            ),
          ],
        ])))),
      ])),
    );
  }

  Widget _buildMainScreen(ThemeColors colors) {
    final isRejected = _verificationStatus?['pendingRequest']?['status'] == 'rejected';
    final rejectionReason = _verificationStatus?['pendingRequest']?['reviewComment'] as String?;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(child: Column(children: [
        _buildHeader(colors),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 4),

            // Rejection banner
            if (isRejected) ...[
              _buildRejectionBanner(rejectionReason),
              const SizedBox(height: 10),
            ],

            // Eligibility card (only shown when NOT eligible)
            if (_eligibility != null && !_localIsEligible) ...[
              _buildEligibilityCard(colors),
              const SizedBox(height: 12),
            ],

            // Eligible content
            if (_localIsEligible) ...[
              _buildInstructionsCard(colors),
              const SizedBox(height: 12),
              if (_recordedVideo != null) ...[
                _buildVideoPreviewCard(colors),
                const SizedBox(height: 12),
              ],
              if (_recordedVideo == null)
                _buildRecordButton(),
              if (_recordedVideo != null && !_uploading) ...[
                _buildSubmitButton(),
              ],
              if (_uploading) _buildUploadingCard(colors),
            ],
          ]),
        )),
      ])),
    );
  }

  Widget _buildHeader(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      color: colors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.arrow_back, color: colors.text, size: 20),
            ),
          ),
          Text('ID Verification', style: TextStyle(fontSize: 17, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: colors.text, letterSpacing: 0.2)),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildRejectionBanner(String? reason) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)]),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Previous Request Rejected', style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            if (reason != null) Text('Reason: $reason', style: const TextStyle(fontSize: 12, fontFamily: 'Outfit', color: Colors.white, height: 1.4)),
            const SizedBox(height: 4),
            const Text('You can submit a new verification request below.', style: TextStyle(fontSize: 11, fontFamily: 'Outfit', color: Colors.white, height: 1.3)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildEligibilityCard(ThemeColors colors) {
    final profileReq = _eligibility?['requirements']?['profileComplete'] as Map<String, dynamic>?;
    final profileCompletion = _localProfileCompletion;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]),
          ),
          child: Row(children: [
            const Icon(Icons.assignment, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(child: Text('Verification Requirements', style: TextStyle(fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2))),
          ]),
        ),
        // Content
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Complete these requirements to unlock verification:', style: TextStyle(fontSize: 13, fontFamily: 'Outfit', color: colors.textSecondary, height: 1.4)),
          const SizedBox(height: 14),
          // Profile completion requirement
          if (profileReq != null)
            _buildRequirementCard(
              colors: colors,
              label: profileReq['label'] as String? ?? 'Profile Completion',
              description: profileReq['description'] as String? ?? 'Complete your profile',
              iconData: Icons.account_circle,
              iconColor: const Color(0xFF6C5CE7),
              current: profileCompletion,
              required: 100,
              isMet: profileCompletion >= 100,
            ),
          const SizedBox(height: 8),
          // Location permission requirement
          _buildLocationRequirementCard(colors),
        ])),
      ]),
    );
  }

  Widget _buildRequirementCard({
    required ThemeColors colors,
    required String label,
    required String description,
    required IconData iconData,
    required Color iconColor,
    required int current,
    required int required,
    required bool isMet,
  }) {
    final progress = isMet ? 1.0 : (current / required).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(iconData, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: colors.text, letterSpacing: 0.2)),
            const SizedBox(height: 2),
            Text(description, style: TextStyle(fontSize: 11, fontFamily: 'Outfit', color: colors.textSecondary, height: 1.4)),
          ])),
          if (isMet) Icon(Icons.check_circle, size: 20, color: colors.success),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(height: 6, color: colors.border, child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1000),
              builder: (context2, v, child2) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: Container(decoration: BoxDecoration(color: isMet ? colors.success : colors.primary, borderRadius: BorderRadius.circular(3))),
              ),
            )),
          )),
          const SizedBox(width: 10),
          Text('$current / $required', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: colors.text)),
        ]),
      ]),
    );
  }

  Widget _buildLocationRequirementCard(ThemeColors colors) {
    const iconColor = Color(0xFFFF9800);
    final granted = _locationPermission == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.location_on, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Location Permission', style: TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: colors.text, letterSpacing: 0.2)),
            const SizedBox(height: 2),
            Text(
              granted ? 'Location access granted — used for address verification' : 'Enable location permission for address verification',
              style: TextStyle(fontSize: 11, fontFamily: 'Outfit', color: colors.textSecondary, height: 1.4),
            ),
          ])),
          Icon(granted ? Icons.check_circle : Icons.chevron_right, size: 20, color: granted ? colors.success : colors.textSecondary),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(height: 6, color: colors.border, child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: granted ? 1.0 : 0.0,
              child: Container(decoration: BoxDecoration(color: granted ? colors.success : colors.primary, borderRadius: BorderRadius.circular(3))),
            )),
          )),
          const SizedBox(width: 10),
          Text(granted ? '1 / 1' : '0 / 1', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: colors.text)),
        ]),
        if (!granted) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openLocationSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.my_location, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text('Open Location Settings', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildInstructionsCard(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.videocam, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Text('Verification Instructions', style: TextStyle(fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: colors.text, letterSpacing: 0.2)),
        ]),
        const SizedBox(height: 10),
        Text(
          'To verify your identity, please record a short selfie video using your front camera and say:',
          style: TextStyle(fontSize: 13, fontFamily: 'Outfit', color: colors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF6C5CE7).withValues(alpha: 0.12), const Color(0xFFA29BFE).withValues(alpha: 0.12)]),
              border: Border(left: BorderSide(color: colors.primary, width: 3)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.format_quote, size: 18, color: colors.primary),
              const SizedBox(height: 4),
              Text(_getInstructionText(), style: TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: colors.text, height: 1.4)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        _buildRequirementItem(colors, 'Use front (selfie) camera'),
        _buildRequirementItem(colors, 'The profile picture and the video face must match.'),
        _buildRequirementItem(colors, 'Maximum $_maxDurationSeconds seconds'),
        _buildRequirementItem(colors, 'Good lighting and clear audio'),
        _buildRequirementItem(colors, 'Show your face clearly'),
      ]),
    );
  }

  Widget _buildRequirementItem(ThemeColors colors, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_circle, size: 16, color: colors.success),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: colors.textSecondary, height: 1.4))),
      ]),
    );
  }

  Widget _buildVideoPreviewCard(ThemeColors colors) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0x2000D4FF), Color(0x200099FF)]),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.videocam, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Text('Video Recorded', style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: colors.text, letterSpacing: 0.2)),
          ]),
          const SizedBox(height: 10),
          if (_videoDuration != null)
            Text('Duration: $_videoDuration seconds', style: TextStyle(fontSize: 13, fontFamily: 'Outfit', color: colors.textSecondary)),
          const SizedBox(height: 10),
          if (!_uploading)
            GestureDetector(
              onTap: () => setState(() => _recordedVideo = null),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: colors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.delete, size: 16, color: colors.error),
                  const SizedBox(width: 6),
                  Text('Remove and Record Again', style: TextStyle(fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: colors.error)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildRecordButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: _gradientButton(
        colors: const [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        onTap: _handleRecordVideo,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.videocam, size: 22, color: Colors.white),
          SizedBox(width: 8),
          Text('Record Verification Video', style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2)),
        ]),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 2),
      child: _gradientButton(
        colors: const [Color(0xFF00D4FF), Color(0xFF0099FF)],
        onTap: _handleSubmit,
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.send, size: 18, color: Colors.white),
          SizedBox(width: 8),
          Text('Submit for Verification', style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2)),
        ]),
      ),
    );
  }

  Widget _buildUploadingCard(ThemeColors colors) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 20, top: 4),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: colors.primary),
        const SizedBox(height: 12),
        Text('Uploading... ${_uploadProgress.toInt()}%', style: TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: colors.text, letterSpacing: 0.2)),
      ]),
    );
  }

  Widget _gradientButton({required List<Color> colors, required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}
