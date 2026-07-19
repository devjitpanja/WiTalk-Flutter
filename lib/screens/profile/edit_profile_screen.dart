import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../api/upload_service.dart';
import '../../services/location_service.dart';
import '../../theme/theme_colors.dart';
import '../../constants/purposes_and_interests.dart';
import '../../widgets/common/city_input.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Circular progress painter (mirrors RN CircularProgress Reanimated component)
// ─────────────────────────────────────────────────────────────────────────────
class _CircularProgressPainter extends CustomPainter {
  final double progress; // 0–100
  final Color color;
  final double strokeWidth;

  _CircularProgressPainter({required this.progress, required this.color, this.strokeWidth = 6});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = const Color(0xFFE5E5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * (progress / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress || old.color != color;
}

class _CircularProgress extends StatefulWidget {
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;

  const _CircularProgress({
    required this.progress,
    required this.color,
  }) : size = 140, strokeWidth = 6;

  @override
  State<_CircularProgress> createState() => _CircularProgressState();
}

class _CircularProgressState extends State<_CircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _prevProgress = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _anim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_CircularProgress old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(begin: _prevProgress, end: widget.progress).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _prevProgress = widget.progress;
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _CircularProgressPainter(
          progress: _anim.value,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert config
// ─────────────────────────────────────────────────────────────────────────────
class _AlertConfig {
  final bool visible;
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool showCancel;
  final String type; // 'danger' | 'warning' | 'info'
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const _AlertConfig({
    this.visible = false,
    this.title = '',
    this.message = '',
    this.confirmText = 'OK',
    this.cancelText = 'Cancel',
    this.showCancel = false,
    this.type = 'danger',
    this.onConfirm,
    this.onCancel,
  });

  _AlertConfig copyWith({bool? visible, String? title, String? message,
    String? confirmText, String? cancelText, bool? showCancel, String? type,
    VoidCallback? onConfirm, VoidCallback? onCancel}) => _AlertConfig(
    visible: visible ?? this.visible,
    title: title ?? this.title,
    message: message ?? this.message,
    confirmText: confirmText ?? this.confirmText,
    cancelText: cancelText ?? this.cancelText,
    showCancel: showCancel ?? this.showCancel,
    type: type ?? this.type,
    onConfirm: onConfirm ?? this.onConfirm,
    onCancel: onCancel ?? this.onCancel,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Controllers
  final _nameCtrl       = TextEditingController();
  final _usernameCtrl   = TextEditingController();
  final _bioCtrl        = TextEditingController();
  final _scrollCtrl     = ScrollController();

  // Loading / saving states
  bool _loading        = true;
  bool _saving         = false;
  bool _uploading      = false;
  bool _checkingUsername = false;
  bool _detectingCity  = false;

  // Profile data
  String? _uid;
  Map<String, dynamic> _originalData = {};

  // Form state
  String _profilePic   = '';
  String _gender       = '';
  String _city         = '';
  String _occupation   = '';
  String _country      = '';
  DateTime? _birthday;
  List<String> _interests = [];
  List<String> _purpose   = [];
  String _preferredLanguage = 'en';
  bool _isVerified     = false;
  File? _selectedImage;

  // Username validation
  bool? _usernameAvailable;
  String _usernameError = '';

  // Eligibility (14-day cooldown)
  Map<String, dynamic> _changeEligibility = {};

  // Has changes
  bool _hasChanges = false;

  // Alert
  _AlertConfig _alertConfig = const _AlertConfig();

  // Bottom sheet controllers — we use showModalBottomSheet for simplicity
  // matching the RN snap-point sizes via isScrollControlled + DraggableScrollableSheet

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onFormChanged);
    _usernameCtrl.addListener(_onUsernameChanged);
    _bioCtrl.addListener(_onFormChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _onFormChanged() {
    _checkHasChanges();
  }

  void _onUsernameChanged() {
    _checkHasChanges();
    final val = _usernameCtrl.text;
    if (val == (_originalData['username'] ?? '')) {
      setState(() { _usernameAvailable = null; _usernameError = ''; });
      return;
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _usernameCtrl.text == val) {
        _checkUsernameAvailability(val);
      }
    });
  }

  void _checkHasChanges() {
    if (!mounted) return;
    final changed = _nameCtrl.text != (_originalData['name'] ?? '') ||
        _usernameCtrl.text != (_originalData['username'] ?? '') ||
        _bioCtrl.text != (_originalData['bio'] ?? '') ||
        _profilePic != (_originalData['profile_pic'] ?? '') ||
        _gender != (_originalData['gender'] ?? '') ||
        _city != (_originalData['city'] ?? '') ||
        _occupation != (_originalData['occupation'] ?? '') ||
        _country != (_originalData['country'] ?? '') ||
        _birthday?.toIso8601String() != (_originalData['birthday'] as DateTime?)?.toIso8601String() ||
        _interests.join(',') != ((_originalData['interests'] as List?)?.join(',') ?? '') ||
        _purpose.join(',') != ((_originalData['purpose'] as List?)?.join(',') ?? '');
    if (_hasChanges != changed) setState(() => _hasChanges = changed);
  }

  int get _displayCompletion {
    int score = 0;
    if (_nameCtrl.text.trim().isNotEmpty) score++;
    if (_usernameCtrl.text.trim().isNotEmpty) score++;
    if (_bioCtrl.text.trim().isNotEmpty) score++;
    if (_profilePic.isNotEmpty) score++;
    if (_gender.isNotEmpty) score++;
    if (_city.trim().isNotEmpty) score++;
    if (_occupation.isNotEmpty) score++;
    if (_country.isNotEmpty) score++;
    if (_birthday != null) score++;
    if (_interests.isNotEmpty) score++;
    if (_purpose.isNotEmpty) score++;
    return ((score / 11) * 100).round();
  }

  void _showAlert(String title, String message, {
    bool showCancel = false,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    String type = 'danger',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    setState(() => _alertConfig = _AlertConfig(
      visible: true, title: title, message: message,
      showCancel: showCancel, confirmText: confirmText, cancelText: cancelText,
      type: type,
      onConfirm: () {
        setState(() => _alertConfig = _alertConfig.copyWith(visible: false));
        onConfirm?.call();
      },
      onCancel: () {
        setState(() => _alertConfig = _alertConfig.copyWith(visible: false));
        onCancel?.call();
      },
    ));
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
      backgroundColor: const Color(0xFF30D158),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      setState(() => _loading = true);
      _uid = await _storage.read(key: 'uid');
      if (_uid == null) return;

      final res = await dioClient.get(AppEndpoints.userProfile(_uid!));
      Map<String, dynamic> userData = {};
      final d = res.data;
      if (d['success'] == true && d['data'] != null) {
        userData = Map<String, dynamic>.from(d['data'] as Map);
      } else if (d['statusCode'] == 200 && d['data'] != null) {
        userData = Map<String, dynamic>.from(d['data'] as Map);
      } else if (d['id'] != null) {
        userData = Map<String, dynamic>.from(d as Map);
      }

      // Workaround: backend sometimes returns empty purpose — fetch from check endpoint
      dynamic purposeRaw = userData['purpose'];
      final purposeEmpty = purposeRaw == null ||
          (purposeRaw is List && purposeRaw.isEmpty) ||
          (purposeRaw is String && (purposeRaw.trim().isEmpty || purposeRaw == '[]'));
      if (purposeEmpty) {
        try {
          final pRes = await dioClient.get(AppEndpoints.purposeInterestsCheck(_uid!));
          final pd = pRes.data;
          if (pd?['statusCode'] == 200 && pd?['data']?['hasPurpose'] == true) {
            userData['purpose'] = pd['data']['purpose'];
          }
        } catch (_) {}
      }

      final interests = _parseStringOrList(userData['interests']);
      final purpose   = _parseStringOrList(userData['purpose']);

      // Filter to valid constants only
      final validInterests = interests.where((i) => ALL_INTEREST_LABELS.contains(i)).toList();
      final validPurpose   = purpose.where((p) => ALL_PURPOSE_LABELS.contains(p)).toList();

      final profileData = {
        'name': userData['name'] ?? '',
        'username': userData['username'] ?? '',
        'bio': userData['bio'] ?? '',
        'profile_pic': userData['profile_pic'] ?? '',
        'gender': userData['gender'] ?? '',
        'city': userData['city'] ?? '',
        'occupation': userData['occupation'] ?? '',
        'country': userData['country'] ?? '',
        'birthday': userData['birthday'] != null ? DateTime.tryParse(userData['birthday'].toString()) : null,
        'interests': validInterests,
        'purpose': validPurpose,
        'preferred_language': userData['preferred_language'] ?? 'en',
        'is_verified': userData['is_verified'] ?? false,
      };

      setState(() {
        _originalData = profileData;
        _nameCtrl.text     = profileData['name'] as String;
        _usernameCtrl.text = profileData['username'] as String;
        _bioCtrl.text      = profileData['bio'] as String;
        _profilePic        = profileData['profile_pic'] as String;
        _gender            = profileData['gender'] as String;
        _city              = profileData['city'] as String;
        _occupation        = profileData['occupation'] as String;
        _country           = profileData['country'] as String;
        _birthday          = profileData['birthday'] as DateTime?;
        _interests         = List<String>.from(profileData['interests'] as List);
        _purpose           = List<String>.from(profileData['purpose'] as List);
        _preferredLanguage = profileData['preferred_language'] as String;
        _isVerified        = profileData['is_verified'] as bool;
        // profile_completion_percentage is unused locally; backend returns it for reference
      });

      // Fetch change eligibility (non-critical)
      try {
        final eRes = await dioClient.get(AppEndpoints.profileChangeEligibility(_uid!));
        if (eRes.data?['data'] != null) {
          setState(() => _changeEligibility = Map<String, dynamic>.from(eRes.data['data'] as Map));
        }
      } catch (_) {}

      // Auto-detect city if blank
      if (_city.isEmpty) {
        try {
          final loc = await locationService.getLocation();
          final geo = await locationService.reverseGeocode(loc.latitude, loc.longitude);
          final detectedCity = geo['city'];
          if (detectedCity != null && mounted) {
            setState(() {
              _city = detectedCity;
              _originalData = {..._originalData, 'city': detectedCity};
            });
            dioClient.put('/v1/user/profile/${_uid!}', data: {'city': detectedCity})
                .catchError((_) => throw Exception('ignored'));
          }
        } catch (_) {}
      }
    } catch (e) {
      _showAlert('Error', 'Failed to load profile data');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _parseStringOrList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      if (raw.trim().isEmpty || raw == '[]') return [];
      try {
        if (raw.startsWith('[')) {
          return raw
              .replaceAll('[', '').replaceAll(']', '')
              .split(',')
              .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
              .where((s) => s.isNotEmpty)
              .toList();
        }
        return [raw];
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  // ── Username check ────────────────────────────────────────────────────────

  Future<void> _checkUsernameAvailability(String username) async {
    final err = _validateUsername(username);
    if (err != null) {
      setState(() { _usernameError = err; _usernameAvailable = false; });
      return;
    }
    setState(() { _checkingUsername = true; _usernameError = ''; });
    try {
      final res = await dioClient.get('${AppEndpoints.checkUsername}/$username');
      if (res.data?['statusCode'] == 200) {
        final available = res.data['data']['available'] as bool? ?? false;
        setState(() {
          _usernameAvailable = available;
          _usernameError = available ? '' : 'Username is already taken';
        });
      }
    } catch (e) {
      final status = (e as dynamic).response?.statusCode;
      if (status == 404) {
        setState(() { _usernameAvailable = true; _usernameError = ''; });
      } else {
        setState(() { _usernameError = 'Error checking username availability'; _usernameAvailable = null; });
      }
    } finally {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  String? _validateUsername(String username) {
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.length > 20) return 'Username must be less than 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    if (RegExp(r'^[0-9]').hasMatch(username)) return 'Username cannot start with a number';
    return null;
  }

  // ── Image pick ────────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null) return;
    await _cropAndSetImage(picked.path);
  }

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 100);
    if (picked == null) return;
    await _cropAndSetImage(picked.path);
  }

  Future<void> _cropAndSetImage(String path) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Photo',
          toolbarColor: context.colors.primary,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Edit Photo', aspectRatioLockEnabled: true, resetAspectRatioEnabled: false),
      ],
    );
    if (cropped != null && mounted) {
      final file = File(cropped.path);
      setState(() {
        _selectedImage = file;
        _profilePic = cropped.path; // local preview
      });
      _checkHasChanges();
    }
  }

  // ── Auto-detect city ──────────────────────────────────────────────────────

  Future<void> _autoDetectCity() async {
    setState(() => _detectingCity = true);
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      } else if (perm == LocationPermission.deniedForever) {
        _showAlert('Permission Required',
            'Location permission is blocked. Please enable it in Settings.');
        return;
      }
      final loc = await locationService.getLocation(forceRefresh: true);
      final geo = await locationService.reverseGeocode(loc.latitude, loc.longitude);
      final city = geo['city'];
      final country = geo['country'];
      if (city == null) {
        _showAlert('Not Found', "Could not determine your city from GPS. Try manually.", type: 'info');
        return;
      }
      setState(() {
        _city = city;
        if (country != null && _country.isEmpty) _country = country;
      });
      _checkHasChanges();
    } catch (e) {
      _showAlert('Location Error', 'Could not get your location. Make sure GPS is enabled.');
    } finally {
      if (mounted) setState(() => _detectingCity = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (!_hasChanges) { context.pop(); return; }

    // Validations
    if (_nameCtrl.text.trim().isEmpty) {
      _showAlert('Error', 'Name is required'); return;
    }
    if (!RegExp(r'^[a-zA-Z\s.]+$').hasMatch(_nameCtrl.text.trim())) {
      _showAlert('Error', 'Name can only contain letters (A–Z) and spaces'); return;
    }
    if (_isVerified && _nameCtrl.text.trim() != (_originalData['name'] ?? '')) {
      _showAlert('Cannot Change Name', 'Verified accounts cannot change their name.', type: 'warning'); return;
    }
    final nameElg = _changeEligibility['name'];
    if (_nameCtrl.text.trim() != (_originalData['name'] ?? '') &&
        nameElg?['can_change'] == false) {
      final dateStr = nameElg?['next_available_date'] != null
          ? DateTime.tryParse(nameElg['next_available_date'].toString())?.toLocal().toString().split(' ')[0]
          : 'later';
      _showAlert('Cannot Change Name',
          'You can only change your name once every 14 days.\nNext available: $dateStr', type: 'warning');
      return;
    }
    if (_usernameCtrl.text.trim().isEmpty) {
      _showAlert('Error', 'Username is required'); return;
    }
    if (_usernameError.isNotEmpty) {
      _showAlert('Error', _usernameError); return;
    }
    if (_usernameAvailable == false) {
      _showAlert('Error', 'Please choose a different username'); return;
    }
    final usrElg = _changeEligibility['username'];
    if (_usernameCtrl.text.trim().toLowerCase() != (_originalData['username'] ?? '') &&
        usrElg?['can_change'] == false) {
      final dateStr = usrElg?['next_available_date'] != null
          ? DateTime.tryParse(usrElg['next_available_date'].toString())?.toLocal().toString().split(' ')[0]
          : 'later';
      _showAlert('Cannot Change Username',
          'You can only change your username once every 14 days.\nNext available: $dateStr', type: 'warning');
      return;
    }
    if (_nameCtrl.text.length > 50) { _showAlert('Error', 'Name must be less than 50 characters'); return; }
    if (_bioCtrl.text.length > 200) { _showAlert('Error', 'Bio must be less than 200 characters'); return; }
    if (_gender.isEmpty) { _showAlert('Required Field', 'Please select your gender to save the profile'); return; }
    if (_birthday == null) { _showAlert('Required Field', 'Please select your birthday to save the profile'); return; }
    if (_purpose.isEmpty) { _showAlert('Required Field', 'Please select at least 1 purpose'); return; }
    if (_interests.isEmpty) { _showAlert('Required Field', 'Please select at least 1 interest'); return; }

    setState(() => _saving = true);
    try {
      String profilePicUrl = _profilePic;

      // Upload new profile pic if changed
      if (_selectedImage != null && _selectedImage!.path != (_originalData['profile_pic'] ?? '')) {
        setState(() => _uploading = true);
        final uploaded = await UploadService.uploadProfilePic(_selectedImage!);
        setState(() => _uploading = false);
        if (uploaded == null) {
          _showAlert('Upload Error', 'Failed to upload image. Please try again.');
          return;
        }
        profilePicUrl = uploaded;

        // Delete old pic from storage
        final oldPic = _originalData['profile_pic'] as String? ?? '';
        if (oldPic.isNotEmpty) {
          UploadService.deleteFile(oldPic).catchError((_) => false);
        }
      }

      final updateData = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'bio': _bioCtrl.text.trim(),
        'profile_pic': profilePicUrl,
        'gender': _gender,
        'city': _city.trim(),
        'occupation': _occupation.trim(),
        'country': ((_originalData['country'] as String?)?.isNotEmpty == true
            ? _originalData['country']
            : _country).toString().trim(),
        'birthday': _birthday?.toIso8601String().split('T')[0],
        'interests': _interests,
        'purpose': _purpose,
        'preferred_language': _preferredLanguage,
      };

      final res = await dioClient.put('/v1/user/profile/${_uid!}', data: updateData);
      if (res.data?['statusCode'] == 200 || res.data?['success'] == true) {
        // profile_completion_percentage returned but not displayed here (handled by _displayCompletion)
        if (mounted) {
          _showSnackBar('Profile updated successfully!');
          context.pop();
        }
      } else {
        throw Exception(res.data?['message'] ?? 'Update failed');
      }
    } catch (e) {
      final isRateLimit = (e as dynamic).response?.statusCode == 429;
      final msg = (e as dynamic).response?.data?['message'] as String? ?? 'Failed to update profile';
      _showAlert(isRateLimit ? 'Update Not Allowed' : 'Error', msg,
          type: isRateLimit ? 'warning' : 'danger');
    } finally {
      if (mounted) setState(() { _saving = false; _uploading = false; });
    }
  }

  void _handleBack() {
    if (_hasChanges) {
      _showAlert(
        'Discard Changes?',
        'You have unsaved changes. Are you sure you want to go back?',
        showCancel: true,
        confirmText: 'Discard',
        cancelText: 'Cancel',
        type: 'danger',
        onConfirm: () {
          _selectedImage = null;
          context.pop();
        },
      );
    } else {
      context.pop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom sheets
  // ─────────────────────────────────────────────────────────────────────────

  void _showImagePickerSheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHandle(colors),
          _sheetHeader('Change Profile Photo', colors, onClose: () => Navigator.pop(context)),
          _sheetOption(Icons.camera_alt, 'Take Photo', colors, onTap: () { Navigator.pop(context); _takePhoto(); }),
          _sheetOption(Icons.photo_library, 'Choose from Gallery', colors, onTap: () { Navigator.pop(context); _pickFromGallery(); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showOccupationSheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHandle(colors),
          _sheetHeader('Select Occupation', colors, onClose: () => Navigator.pop(context)),
          ...['Student', 'Working professional', 'Homemaker/Housewife'].map((o) => _sheetOptionWithCheck(
            o, _occupation == o, colors,
            onTap: () { setState(() => _occupation = o); _checkHasChanges(); Navigator.pop(context); },
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showCountrySheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.70,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _CountrySheetContent(
          selectedCountry: _country,
          onSelect: (c) { setState(() => _country = c); _checkHasChanges(); Navigator.pop(context); },
        ),
      ),
    );
  }

  void _showInterestsSheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _InterestsSheetContent(
          selectedInterests: List<String>.from(_interests),
          onChanged: (updated) { setState(() => _interests = updated); _checkHasChanges(); },
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showPurposeSheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.bottomSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _PurposeSheetContent(
          selectedPurpose: List<String>.from(_purpose),
          onChanged: (updated) { setState(() => _purpose = updated); _checkHasChanges(); },
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showDatePicker() async {
    final colors = context.colors;
    final initial = _birthday ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: colors.primary,
            onPrimary: Colors.white,
            surface: colors.bottomSheetBg,
            onSurface: colors.text,
          ),
          dialogBackgroundColor: colors.bottomSheetBg,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _birthday = picked);
      _checkHasChanges();
    }
  }

  Future<void> _handleGenderChangeRequest() async {
    try {
      final res = await dioClient.get(AppEndpoints.supportUser);
      if (res.data?['success'] == true) {
        final supportUser = res.data['data'] as Map<String, dynamic>;
        if (mounted) {
          context.push('/chat-conversation', extra: {
            'conversationId': null,
            'otherUser': {
              'id': supportUser['id'],
              'name': supportUser['name'],
              'username': supportUser['username'],
              'profile_pic': supportUser['profile_pic'],
            },
            'initialMessage': 'Hi WiTalk Support, I would like to request a gender change on my account. Please update my gender to: [write your preferred gender here]',
          });
        }
      }
    } catch (_) {
      _showAlert('Error', 'Something went wrong. Please try again.', type: 'danger');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sheet helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sheetHandle(ThemeColors colors) => Container(
    width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: colors.textTertiary.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
  );

  Widget _sheetHeader(String title, ThemeColors colors, {required VoidCallback onClose}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 16, 16),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: TextStyle(color: colors.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      GestureDetector(onTap: onClose, child: Icon(Icons.close, color: colors.text, size: 24)),
    ]),
  );

  Widget _sheetOption(IconData icon, String label, ThemeColors colors, {required VoidCallback onTap}) =>
    InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Icon(icon, color: colors.primary, size: 24),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: colors.text, fontSize: 16, fontFamily: 'Outfit')),
      ]),
    ));

  Widget _sheetOptionWithCheck(String label, bool isSelected, ThemeColors colors, {required VoidCallback onTap}) =>
    InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: colors.text, fontSize: 16, fontFamily: 'Outfit')),
        if (isSelected) Icon(Icons.check, color: colors.primary, size: 22),
      ]),
    ));

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 16),
          Text('Loading profile...', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 16)),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(children: [
        SafeArea(child: Column(children: [
          // Header
          _buildHeader(colors),
          // Scrollable content
          Expanded(child: SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            child: Column(children: [
              _buildProfilePicSection(colors, isDark),
              _buildFormSection(colors, isDark),
            ]),
          )),
        ])),

        // Custom alert dialog overlay
        if (_alertConfig.visible) _buildAlertDialog(colors),
      ]),
    );
  }

  Widget _buildHeader(ThemeColors colors) {
    final canSave = _hasChanges && _usernameAvailable != false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(children: [
        IconButton(
          onPressed: _handleBack,
          icon: Icon(Icons.arrow_back, color: colors.text),
        ),
        Expanded(child: Text('Edit Profile', textAlign: TextAlign.center,
          style: TextStyle(color: colors.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600))),
        TextButton(
          onPressed: (_saving || !canSave) ? null : _handleSave,
          child: _saving
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
              : Text('Save', style: TextStyle(
                  color: canSave ? colors.primary : colors.textTertiary,
                  fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildProfilePicSection(ThemeColors colors, bool isDark) {
    final completion = _displayCompletion.toDouble();
    final isLocal = _selectedImage != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Column(children: [
        SizedBox(
          width: 140, height: 140,
          child: Stack(alignment: Alignment.center, children: [
            _CircularProgress(progress: completion, color: colors.primary),
            GestureDetector(
              onTap: _showImagePickerSheet,
              child: Stack(alignment: Alignment.bottomRight, children: [
                ClipOval(child: SizedBox(
                  width: 118, height: 118,
                  child: isLocal
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : (_profilePic.isNotEmpty
                          ? CachedNetworkImage(imageUrl: _profilePic, fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: colors.surface),
                              errorWidget: (_, __, ___) => Container(color: colors.surface,
                                  child: Icon(Icons.person, color: colors.textTertiary, size: 40)))
                          : Container(color: colors.surface,
                              child: Icon(Icons.person, color: colors.textTertiary, size: 40))),
                )),
                Container(
                  width: 32, height: 32, margin: const EdgeInsets.only(right: 2, bottom: 2),
                  decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle,
                    border: Border.all(color: colors.background, width: 2)),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                ),
                if (_uploading) Positioned.fill(child: ClipOval(child: Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                ))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Text('Change profile photo', style: TextStyle(color: colors.primary, fontSize: 14, fontFamily: 'Outfit')),
        const SizedBox(height: 4),
        Text('${_displayCompletion}% Complete',
            style: TextStyle(color: colors.primary, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _displayCompletion == 100 ? 'Your profile is complete!' : 'Complete your profile to get better matches',
            style: TextStyle(color: colors.textSecondary, fontSize: 12, fontFamily: 'Outfit'),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }

  Widget _buildFormSection(ThemeColors colors, bool isDark) {
    final nameElg = _changeEligibility['name'];
    final usrElg  = _changeEligibility['username'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Name ──────────────────────────────────────────────────────────
        _fieldLabel('Name', colors),
        _textField(
          controller: _nameCtrl,
          hint: 'Enter your name',
          maxLength: 50,
          enabled: !_isVerified,
          colors: colors, isDark: isDark,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s.]'))],
        ),
        if (_isVerified)
          _cooldownRow(Icons.lock, 'Verified accounts cannot change their name', colors.textSecondary)
        else if (nameElg?['can_change'] == false)
          _cooldownRow(Icons.schedule, 'Next change available: ${_fmtDate(nameElg?['next_available_date'])}', colors.warning),
        _charCount(_nameCtrl.text.length, 50, colors),
        const SizedBox(height: 24),

        // ── Username ──────────────────────────────────────────────────────
        _fieldLabel('Username', colors),
        _textField(
          controller: _usernameCtrl,
          hint: 'Enter username',
          maxLength: 20,
          colors: colors, isDark: isDark,
          borderColor: _usernameError.isNotEmpty ? colors.error
              : _usernameAvailable == true ? colors.success : null,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]'))],
        ),
        if (_checkingUsername)
          Padding(padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
              const SizedBox(width: 6),
              Text('Checking availability...', style: TextStyle(color: colors.textSecondary, fontSize: 12, fontFamily: 'Outfit')),
            ]))
        else if (_usernameError.isNotEmpty)
          _validationRow(Icons.error, _usernameError, colors.error)
        else if (_usernameAvailable == true && _usernameCtrl.text != (_originalData['username'] ?? ''))
          _validationRow(Icons.check_circle, 'Username is available', colors.success),
        if (usrElg?['can_change'] == false)
          _cooldownRow(Icons.schedule, 'Next change available: ${_fmtDate(usrElg?['next_available_date'])}', colors.warning),
        _charCount(_usernameCtrl.text.length, 20, colors),
        const SizedBox(height: 24),

        // ── Bio ───────────────────────────────────────────────────────────
        _fieldLabel('About', colors),
        _textField(
          controller: _bioCtrl,
          hint: 'Write about you...',
          maxLength: 200,
          maxLines: 3,
          colors: colors, isDark: isDark,
        ),
        _charCount(_bioCtrl.text.length, 200, colors),
        const SizedBox(height: 24),

        // ── Gender (locked + request change link) ─────────────────────────
        _fieldLabel('Gender', colors),
        Opacity(
          opacity: 0.5,
          child: _pickerButton(
            label: _gender.isNotEmpty ? _gender : 'Gender',
            isPlaceholder: _gender.isEmpty,
            onTap: null, // gender is locked; changed via support chat
            colors: colors,
          ),
        ),
        GestureDetector(
          onTap: _handleGenderChangeRequest,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.mail_outline, size: 14, color: Color(0xFF007AFF)),
              const SizedBox(width: 4),
              const Text('Request Gender Change',
                style: TextStyle(color: Color(0xFF007AFF), fontSize: 13, fontFamily: 'Outfit')),
            ]),
          ),
        ),
        const SizedBox(height: 24),

        // ── City ──────────────────────────────────────────────────────────
        _fieldLabel('City', colors),
        CityInput(
          value: _city,
          onCitySelect: (city) { setState(() => _city = city); _checkHasChanges(); },
          onCitySelectFull: (city, _, country) {
            setState(() {
              _city = city;
              if (country != null && country.isNotEmpty) _country = country;
            });
            _checkHasChanges();
          },
          placeholder: 'Search and select your city',
          rightAction: GestureDetector(
            onTap: _detectingCity ? null : _autoDetectCity,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _detectingCity
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                  : Icon(Icons.my_location, size: 18, color: colors.primary),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Birthday ──────────────────────────────────────────────────────
        _fieldLabel('Birthday', colors),
        _pickerButton(
          label: _birthday != null
              ? '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}'
              : 'Select birthday',
          isPlaceholder: _birthday == null,
          icon: Icons.calendar_today,
          onTap: _showDatePicker,
          colors: colors,
        ),
        const SizedBox(height: 24),

        // ── Occupation ────────────────────────────────────────────────────
        _fieldLabel('Occupation', colors),
        _pickerButton(
          label: _occupation.isNotEmpty ? _occupation : 'Select occupation',
          isPlaceholder: _occupation.isEmpty,
          onTap: _showOccupationSheet,
          colors: colors,
        ),
        const SizedBox(height: 24),

        // ── Country (locked once set) ─────────────────────────────────────
        _fieldLabel('Country', colors),
        Opacity(
          opacity: (_originalData['country'] as String?)?.isNotEmpty == true ? 0.5 : 1.0,
          child: _pickerButton(
            label: _country.isNotEmpty ? _country : 'Select country',
            isPlaceholder: _country.isEmpty,
            onTap: (_originalData['country'] as String?)?.isNotEmpty == true
                ? null
                : _showCountrySheet,
            colors: colors,
          ),
        ),
        const SizedBox(height: 24),

        // ── Purpose ───────────────────────────────────────────────────────
        _fieldLabel('Purpose (${_purpose.length})', colors),
        _tagsButton(
          tags: _purpose,
          placeholder: 'Select your purpose',
          onTap: _showPurposeSheet,
          colors: colors,
        ),
        const SizedBox(height: 24),

        // ── Interests ─────────────────────────────────────────────────────
        _fieldLabel('Interests (${_interests.length})', colors),
        _tagsButton(
          tags: _interests,
          placeholder: 'Add your interests',
          onTap: _showInterestsSheet,
          colors: colors,
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Field widgets ─────────────────────────────────────────────────────────

  Widget _fieldLabel(String text, ThemeColors colors) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(color: colors.text, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required ThemeColors colors,
    required bool isDark,
    int? maxLength,
    int maxLines = 1,
    bool enabled = true,
    Color? borderColor,
    bool autocorrect = true,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final effective = borderColor ?? colors.border;
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      maxLines: maxLines,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.placeholder, fontFamily: 'Outfit'),
        counterText: '',
        filled: true,
        fillColor: colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: effective)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: effective)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1.5)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: effective.withOpacity(0.4))),
      ),
    );
  }

  Widget _pickerButton({
    required String label,
    required bool isPlaceholder,
    required ThemeColors colors,
    VoidCallback? onTap,
    IconData icon = Icons.arrow_drop_down,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label,
          style: TextStyle(
            color: isPlaceholder ? colors.placeholder : colors.text,
            fontFamily: 'Outfit', fontSize: 16))),
        Icon(icon, color: colors.textTertiary, size: 22),
      ]),
    ),
  );

  Widget _tagsButton({
    required List<String> tags,
    required String placeholder,
    required ThemeColors colors,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(child: tags.isNotEmpty
              ? Wrap(spacing: 6, runSpacing: 6,
                  children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(t, style: TextStyle(color: colors.primary, fontSize: 14, fontFamily: 'Outfit')),
                  )).toList())
              : Text(placeholder, style: TextStyle(color: colors.placeholder, fontFamily: 'Outfit', fontSize: 16))),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 14, color: colors.textTertiary),
        ]),
      ),
    );
  }

  Widget _charCount(int current, int max, ThemeColors colors) => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$current/$max', style: TextStyle(color: colors.textTertiary, fontSize: 12, fontFamily: 'Outfit')),
    ),
  );

  Widget _validationRow(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12, fontFamily: 'Outfit'))),
    ]),
  );

  Widget _cooldownRow(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12, fontFamily: 'Outfit'))),
    ]),
  );

  String _fmtDate(dynamic raw) {
    if (raw == null) return 'later';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return 'later';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  // ── Alert dialog ──────────────────────────────────────────────────────────

  Widget _buildAlertDialog(ThemeColors colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _alertConfig.type == 'warning' ? colors.warning
        : _alertConfig.type == 'info' ? colors.primary : colors.error;
    return Positioned.fill(child: GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_alertConfig.title,
                style: TextStyle(color: colors.text, fontSize: 17, fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(_alertConfig.message,
                style: TextStyle(color: colors.textSecondary, fontSize: 14, fontFamily: 'Outfit')),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (_alertConfig.showCancel) ...[
                  TextButton(
                    onPressed: _alertConfig.onCancel,
                    child: Text(_alertConfig.cancelText,
                      style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: _alertConfig.onConfirm,
                  child: Text(_alertConfig.confirmText,
                    style: TextStyle(color: typeColor, fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        )),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Country sheet (stateful, has own search)
// ─────────────────────────────────────────────────────────────────────────────
class _CountrySheetContent extends StatefulWidget {
  final String selectedCountry;
  final ValueChanged<String> onSelect;
  const _CountrySheetContent({required this.selectedCountry, required this.onSelect});

  @override
  State<_CountrySheetContent> createState() => _CountrySheetContentState();
}

class _CountrySheetContentState extends State<_CountrySheetContent> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<String> get _filtered {
    if (_query.trim().isEmpty) return COUNTRIES;
    final q = _query.toLowerCase();
    return COUNTRIES.where((c) => c.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: colors.textTertiary.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Select Country', style: TextStyle(color: colors.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          GestureDetector(
            onTap: () { setState(() => _query = ''); _searchCtrl.clear(); Navigator.pop(context); },
            child: Icon(Icons.close, color: colors.text)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(children: [
            const SizedBox(width: 10),
            Icon(Icons.search, color: colors.textSecondary, size: 20),
            const SizedBox(width: 6),
            Expanded(child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: colors.text, fontFamily: 'Outfit'),
              decoration: InputDecoration(
                hintText: 'Search countries...', hintStyle: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit'),
                border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => setState(() => _query = v),
            )),
            if (_query.isNotEmpty) GestureDetector(
              onTap: () { setState(() => _query = ''); _searchCtrl.clear(); },
              child: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.close, size: 18, color: colors.textSecondary)),
            ),
          ]),
        ),
      ),
      Expanded(child: _filtered.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.search_off, size: 48, color: colors.textTertiary),
              const SizedBox(height: 12),
              Text('No countries found', style: TextStyle(color: colors.textSecondary, fontFamily: 'Outfit', fontSize: 16)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                return InkWell(
                  onTap: () => widget.onSelect(c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(c, style: TextStyle(color: colors.text, fontSize: 16, fontFamily: 'Outfit')),
                      if (widget.selectedCountry == c) Icon(Icons.check, color: colors.primary, size: 22),
                    ]),
                  ),
                );
              },
            )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interests sheet (stateful, manages local selection + search)
// ─────────────────────────────────────────────────────────────────────────────
class _InterestsSheetContent extends StatefulWidget {
  final List<String> selectedInterests;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onClose;
  const _InterestsSheetContent({required this.selectedInterests, required this.onChanged, required this.onClose});

  @override
  State<_InterestsSheetContent> createState() => _InterestsSheetContentState();
}

class _InterestsSheetContentState extends State<_InterestsSheetContent> {
  final _searchCtrl = TextEditingController();
  late List<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedInterests);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<InterestCategory> get _filtered {
    if (_query.trim().isEmpty) return INTEREST_CATEGORIES;
    final q = _query.toLowerCase();
    return INTEREST_CATEGORIES
        .map((cat) => InterestCategory(
            id: cat.id, title: cat.title, emoji: cat.emoji,
            interests: cat.interests.where((i) => i.label.toLowerCase().contains(q)).toList()))
        .where((cat) => cat.interests.isNotEmpty)
        .toList();
  }

  void _toggle(String label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else if (_selected.length < 10) {
        _selected.add(label);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You can select up to 10 interests only', style: TextStyle(fontFamily: 'Outfit')),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
        return;
      }
      widget.onChanged(List<String>.from(_selected));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: colors.textTertiary.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Select Interests', style: TextStyle(color: colors.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          GestureDetector(onTap: widget.onClose, child: Icon(Icons.close, color: colors.text)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(children: [
              const SizedBox(width: 10),
              Icon(Icons.search, color: colors.textTertiary, size: 20),
              const SizedBox(width: 6),
              Expanded(child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: colors.text, fontFamily: 'Outfit', fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search interests...', hintStyle: TextStyle(color: colors.textTertiary, fontFamily: 'Outfit'),
                  border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
                onChanged: (v) => setState(() => _query = v),
              )),
              if (_query.isNotEmpty) GestureDetector(
                onTap: () { setState(() => _query = ''); _searchCtrl.clear(); },
                child: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.close, size: 18, color: colors.textTertiary)),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight,
            child: Text('${_selected.length}/10 selected',
              style: TextStyle(color: colors.textTertiary, fontSize: 12, fontFamily: 'Outfit'))),
        ]),
      ),
      Expanded(child: _filtered.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.search_off, size: 40, color: colors.textTertiary),
              const SizedBox(height: 8),
              Text('No interests found', style: TextStyle(color: colors.textTertiary, fontFamily: 'Outfit', fontSize: 15)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final cat = _filtered[i];
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('${cat.emoji}  ${cat.title}',
                      style: TextStyle(color: colors.text, fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                  ),
                  Wrap(spacing: 10, runSpacing: 10,
                    children: cat.interests.map((interest) {
                      final sel = _selected.contains(interest.label);
                      return GestureDetector(
                        onTap: () => _toggle(interest.label),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? colors.primary : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? colors.primary : colors.border),
                          ),
                          child: Text(interest.label,
                            style: TextStyle(
                              color: sel ? Colors.white : colors.textSecondary,
                              fontSize: 14, fontFamily: 'Outfit',
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ]);
              },
            )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Purpose sheet (stateful, single-select)
// ─────────────────────────────────────────────────────────────────────────────
class _PurposeSheetContent extends StatefulWidget {
  final List<String> selectedPurpose;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onClose;
  const _PurposeSheetContent({required this.selectedPurpose, required this.onChanged, required this.onClose});

  @override
  State<_PurposeSheetContent> createState() => _PurposeSheetContentState();
}

class _PurposeSheetContentState extends State<_PurposeSheetContent> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedPurpose);
  }

  void _toggle(String label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected = [];
      } else {
        _selected = [label]; // single select
      }
      widget.onChanged(List<String>.from(_selected));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: colors.textTertiary.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Select Purpose', style: TextStyle(color: colors.text, fontSize: 18, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
          GestureDetector(onTap: widget.onClose, child: Icon(Icons.close, color: colors.text)),
        ]),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Wrap(spacing: 10, runSpacing: 10,
          children: PURPOSE_OPTIONS.map((p) {
            final sel = _selected.contains(p.label);
            return GestureDetector(
              onTap: () => _toggle(p.label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? colors.primary : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? colors.primary : colors.border),
                ),
                child: Text(p.label,
                  style: TextStyle(
                    color: sel ? Colors.white : colors.textSecondary,
                    fontSize: 14, fontFamily: 'Outfit',
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
              ),
            );
          }).toList(),
        ),
      )),
    ]);
  }
}
