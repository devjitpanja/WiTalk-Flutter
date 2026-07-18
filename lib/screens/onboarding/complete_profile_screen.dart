import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

enum _Step { identity, about, photo }

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.identity;
  bool _saving = false;
  bool _loading = true;
  String? _uid;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  String _gender = '';
  DateTime? _birthday;
  File? _profileImage;
  String? _existingProfilePic;

  bool? _usernameAvailable;
  String _usernameError = '';
  bool _checkingUsername = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _totalSteps = 5;
  int get _stepIndex => _step.index + 1;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_fadeCtrl);
    _fadeCtrl.forward();
    _loadUser();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString('uid');
    if (_uid == null) { if (mounted) context.go('/auth'); return; }
    try {
      final res = await dioClient.get('/v1/user/$_uid');
      if (res.data['success'] == true) {
        final d = res.data['data'];
        final nameParts = (d['name'] ?? '').trim().split(RegExp(r'\s+'));
        _firstNameCtrl.text = nameParts.isNotEmpty ? nameParts[0] : '';
        _lastNameCtrl.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        _usernameCtrl.text = d['username'] ?? '';
        _gender = d['gender'] ?? '';
        if (d['birthday'] != null) _birthday = DateTime.tryParse(d['birthday']);
        _existingProfilePic = d['profile_pic'];
        if (_usernameCtrl.text.isNotEmpty) {
          final valid = RegExp(r'^[a-z0-9_]{5,20}$').hasMatch(_usernameCtrl.text.toLowerCase());
          if (valid) _usernameAvailable = true;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _nextStep() {
    _fadeCtrl.reset();
    setState(() => _step = _Step.values[_step.index + 1]);
    _fadeCtrl.forward();
  }

  void _prevStep() {
    if (_step == _Step.identity) return;
    _fadeCtrl.reset();
    setState(() => _step = _Step.values[_step.index - 1]);
    _fadeCtrl.forward();
  }

  Future<void> _checkUsername(String value) async {
    if (value.length < 3) { setState(() { _usernameAvailable = null; _usernameError = ''; }); return; }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value.toLowerCase())) {
      setState(() { _usernameAvailable = false; _usernameError = 'Only letters, numbers, underscores (3-20 chars)'; });
      return;
    }
    setState(() { _checkingUsername = true; _usernameError = ''; });
    try {
      final res = await dioClient.get('/v1/user/check-username?username=${value.toLowerCase()}');
      final available = res.data['available'] == true;
      if (mounted) setState(() { _usernameAvailable = available; _usernameError = available ? '' : 'Username already taken'; _checkingUsername = false; });
    } catch (_) { if (mounted) setState(() => _checkingUsername = false); }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop Photo', toolbarColor: AppColors.background, toolbarWidgetColor: Colors.white, initAspectRatio: CropAspectRatioPreset.square, lockAspectRatio: true),
        IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped != null && mounted) setState(() => _profileImage = File(cropped.path));
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final nameFull = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
      String? uploadedPicUrl;
      if (_profileImage != null) {
        final formData = FormData.fromMap({'file': await MultipartFile.fromFile(_profileImage!.path, filename: 'avatar.jpg')});
        final uploadRes = await dioClient.post('/v1/upload/profile-pic', data: formData);
        uploadedPicUrl = uploadRes.data['url'];
      }
      final payload = {
        'name': nameFull,
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'gender': _gender,
        'birthday': _birthday?.toIso8601String(),
        if (uploadedPicUrl != null) 'profile_pic': uploadedPicUrl,
      };
      await dioClient.put('/v1/user/$_uid/profile', data: payload);
      if (mounted) context.go('/purpose-interests');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red.shade700));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
            : Column(children: [
                _buildHeader(),
                _buildProgressBar(),
                Expanded(child: FadeTransition(opacity: _fadeAnim, child: _buildStepContent())),
                _buildBottomButton(),
              ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      if (_step != _Step.identity)
        GestureDetector(
          onTap: _prevStep,
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
        ),
      const Spacer(),
      Text('Step $_stepIndex of $_totalSteps', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
    ]),
  );

  Widget _buildProgressBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Row(children: List.generate(_totalSteps, (i) => Expanded(
      child: Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: i < _stepIndex ? AppColors.primaryButton : AppColors.border, borderRadius: BorderRadius.circular(2))),
    ))),
  );

  Widget _buildStepContent() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    child: switch (_step) {
      _Step.identity => _buildIdentityStep(),
      _Step.about => _buildAboutStep(),
      _Step.photo => _buildPhotoStep(),
    },
  );

  Widget _buildIdentityStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('What\'s your name?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit')),
    const SizedBox(height: 8),
    const Text('This is how others will see you', style: TextStyle(fontSize: 15, color: AppColors.textTertiary, fontFamily: 'Outfit')),
    const SizedBox(height: 32),
    _field(_firstNameCtrl, 'First Name', Icons.person_outline),
    const SizedBox(height: 16),
    _field(_lastNameCtrl, 'Last Name', Icons.person_outline),
    const SizedBox(height: 24),
    const Text('Choose a username', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Outfit')),
    const SizedBox(height: 12),
    _buildUsernameField(),
    const SizedBox(height: 100),
  ]);

  Widget _buildAboutStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Tell us about yourself', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit')),
    const SizedBox(height: 8),
    const Text('Helps us connect you better', style: TextStyle(fontSize: 15, color: AppColors.textTertiary, fontFamily: 'Outfit')),
    const SizedBox(height: 32),
    const Text('Gender', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Outfit')),
    const SizedBox(height: 12),
    _buildGenderPicker(),
    const SizedBox(height: 28),
    const Text('Birthday', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Outfit')),
    const SizedBox(height: 12),
    _buildBirthdayPicker(),
    const SizedBox(height: 100),
  ]);

  Widget _buildPhotoStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Add a profile photo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Outfit')),
    const SizedBox(height: 8),
    const Text('Optional — you can add one later', style: TextStyle(fontSize: 15, color: AppColors.textTertiary, fontFamily: 'Outfit')),
    const SizedBox(height: 48),
    Center(child: GestureDetector(
      onTap: _pickImage,
      child: Container(width: 140, height: 140,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface,
          border: Border.all(color: AppColors.primaryButton, width: 2),
          image: _profileImage != null ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
              : (_existingProfilePic != null ? DecorationImage(image: NetworkImage(_existingProfilePic!), fit: BoxFit.cover) : null)),
        child: _profileImage == null && _existingProfilePic == null
            ? const Icon(Icons.add_a_photo_outlined, color: AppColors.textTertiary, size: 40) : null),
    )),
    const SizedBox(height: 24),
    Center(child: TextButton(onPressed: _pickImage,
      child: const Text('Choose from gallery', style: TextStyle(color: AppColors.primaryButton, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600)))),
    const SizedBox(height: 100),
  ]);

  Widget _field(TextEditingController ctrl, String hint, IconData icon) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
    decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
      filled: true, fillColor: AppColors.surface, hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryButton))),
  );

  Widget _buildUsernameField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(
      controller: _usernameCtrl,
      style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]'))],
      onChanged: (v) => _checkUsername(v.toLowerCase()),
      decoration: InputDecoration(hintText: 'username', prefixText: '@',
        prefixStyle: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit'),
        suffixIcon: _checkingUsername
            ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
            : (_usernameAvailable == null ? null : Icon(_usernameAvailable! ? Icons.check_circle : Icons.cancel, color: _usernameAvailable! ? AppColors.success : AppColors.error)),
        filled: true, fillColor: AppColors.surface, hintStyle: const TextStyle(color: AppColors.placeholder, fontFamily: 'Outfit'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryButton))),
    ),
    if (_usernameError.isNotEmpty)
      Padding(padding: const EdgeInsets.only(top: 6, left: 4),
        child: Text(_usernameError, style: const TextStyle(color: AppColors.error, fontSize: 12, fontFamily: 'Outfit'))),
  ]);

  Widget _buildGenderPicker() => Row(children: ['Male', 'Female', 'Other'].map((g) => Expanded(
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(onTap: () => setState(() => _gender = g),
        child: Container(height: 48,
          decoration: BoxDecoration(color: _gender == g ? AppColors.primaryButton : AppColors.surface,
            borderRadius: BorderRadius.circular(12), border: Border.all(color: _gender == g ? AppColors.primaryButton : AppColors.border)),
          child: Center(child: Text(g, style: TextStyle(color: _gender == g ? Colors.white : AppColors.textSecondary, fontFamily: 'Outfit', fontWeight: FontWeight.w500)))))),
  )).toList());

  Widget _buildBirthdayPicker() {
    final formatted = _birthday != null ? '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}' : 'Select your birthday';
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(context: context,
          initialDate: _birthday ?? DateTime(now.year - 18), firstDate: DateTime(1940), lastDate: DateTime(now.year - 13),
          builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primaryButton)), child: child!));
        if (picked != null && mounted) setState(() => _birthday = picked);
      },
      child: Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.cake_outlined, color: AppColors.textTertiary, size: 20),
          const SizedBox(width: 12),
          Text(formatted, style: TextStyle(color: _birthday != null ? Colors.white : AppColors.placeholder, fontFamily: 'Outfit', fontSize: 15)),
        ])),
    );
  }

  Widget _buildBottomButton() {
    final canProceed = switch (_step) {
      _Step.identity => _firstNameCtrl.text.trim().isNotEmpty && _usernameCtrl.text.trim().length >= 3 && _usernameAvailable == true,
      _Step.about => _gender.isNotEmpty && _birthday != null,
      _Step.photo => true,
    };
    final isLastStep = _step == _Step.photo;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
      child: ElevatedButton(
        onPressed: canProceed ? (isLastStep ? _submit : _nextStep) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canProceed ? AppColors.primaryButton : AppColors.border,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _saving
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(isLastStep ? 'Continue' : 'Next', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
      ),
    );
  }
}
