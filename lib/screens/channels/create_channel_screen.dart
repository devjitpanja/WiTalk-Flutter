import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/channel_api.dart';
import '../../api/dio_client.dart';
import '../../theme/theme_colors.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  Timer? _usernameTimer;

  String _channelType = 'public'; // 'public' or 'private'
  XFile? _channelPic;
  String? _usernameStatus; // null, 'checking', 'available', 'taken', 'invalid'
  bool _loading = false;
  bool? _isVerified; // null = checking

  bool _nameFocused = false;
  bool _descFocused = false;
  bool _usernameFocused = false;

  final RegExp _usernameRegex = RegExp(r'^[a-z0-9_]{5,20}$');

  @override
  void initState() {
    super.initState();
    _checkVerified();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _usernameController.dispose();
    _usernameTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    try {
      final uid = await _storage.read(key: 'uid');
      if (uid == null) {
        setState(() => _isVerified = false);
        return;
      }
      final res = await dioClient.get('/v1/user/$uid');
      final isVerified = res.data?['data']?['is_verified'] == true ||
          res.data?['data']?['is_verified'] == 1;
      setState(() => _isVerified = isVerified);
    } catch (_) {
      setState(() => _isVerified = false);
    }
  }

  void _onUsernameChanged(String text) {
    final sanitized = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    _usernameController.value = TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(offset: sanitized.length),
    );

    _usernameTimer?.cancel();
    if (sanitized.isEmpty) {
      setState(() => _usernameStatus = null);
      return;
    }

    if (!_usernameRegex.hasMatch(sanitized)) {
      setState(() => _usernameStatus = 'invalid');
      return;
    }

    setState(() => _usernameStatus = 'checking');
    _usernameTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await ChannelApi.checkUsername(sanitized);
        final available = res.data?['available'] == true;
        if (mounted) {
          setState(() => _usernameStatus = available ? 'available' : 'taken');
        }
      } catch (_) {
        if (mounted) {
          setState(() => _usernameStatus = 'invalid');
        }
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _channelPic = picked);
      }
    } catch (e) {
      _showAlert('Error', 'Failed to select image');
    }
  }

  void _showImagePickerModal() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Channel Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.photo_library, color: colors.primary),
                title: Text('Choose from Gallery', style: TextStyle(color: colors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: colors.primary),
                title: Text('Take a Photo', style: TextStyle(color: colors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadImage(XFile file, String userId) async {
    try {
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'channel_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'user_id': userId,
      });

      final res = await dioClient.post('/v1/files/upload', data: formData);
      if (res.statusCode == 200 && res.data?['success'] == true && res.data?['file']?['url'] != null) {
        return res.data['file']['url'] as String;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    final description = _descController.text.trim();
    final username = _usernameController.text.trim();

    if (name.length < 3) {
      _showAlert('Required', 'Channel name must be at least 3 characters');
      return;
    }
    if (_channelPic == null) {
      _showAlert('Required', 'Please add a channel photo');
      return;
    }
    if (_channelType == 'public' && _usernameStatus != 'available') {
      _showAlert('Required', 'Please choose an available username handle');
      return;
    }

    setState(() => _loading = true);
    try {
      final userId = await _storage.read(key: 'uid');
      if (userId == null) throw Exception('Not authenticated');

      final iconUrl = await _uploadImage(_channelPic!, userId);
      if (iconUrl == null) {
        _showAlert('Upload Failed', 'Could not upload channel photo');
        return;
      }

      final res = await ChannelApi.create({
        'name': name,
        'description': description.isNotEmpty ? description : null,
        'channel_type': _channelType,
        'icon': iconUrl,
        if (_channelType == 'public') 'username': username,
      });

      final channel = res.data?['channel'];
      if (channel != null && mounted) {
        final channelId = channel['id']?.toString() ?? '';
        context.pushReplacement('/channel/$channelId', extra: {'channel': channel});
      }
    } catch (err) {
      _showAlert('Error', 'Could not create channel. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isVerified == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    if (_isVerified == false) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          leading: IconButton(
            icon: Icon(Icons.close, color: colors.text),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'New Channel',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: colors.text),
          ),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified, size: 64, color: colors.textTertiary),
                const SizedBox(height: 20),
                Text(
                  'Verified Account Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Only verified users can create channels. Get verified to start broadcasting to your audience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isFormValid = _nameController.text.trim().length >= 3 &&
        _channelPic != null &&
        (_channelType != 'public' || _usernameStatus == 'available');

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'New Channel',
          style: TextStyle(
            fontSize: 17,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            // Photo Picker Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accent.withOpacity(0.15), colors.accent.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImagePickerModal,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _channelPic != null
                                  ? [colors.accent, colors.primary]
                                  : [colors.border, colors.border],
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            backgroundColor: colors.background,
                            backgroundImage: _channelPic != null
                                ? NetworkImage(_channelPic!.path)
                                : null,
                            child: _channelPic == null
                                ? Icon(Icons.add_a_photo, size: 36, color: colors.textSecondary)
                                : null,
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [colors.accent, colors.primary]),
                          ),
                          child: Icon(
                            _channelPic != null ? Icons.edit : Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _channelPic != null ? 'Tap to change photo' : 'Add channel photo *',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Outfit',
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Form Fields
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel Name Field
                  Container(
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _nameFocused ? colors.primary : colors.border.withOpacity(0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CHANNEL NAME',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                color: colors.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${_nameController.text.length}/100',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Outfit',
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Focus(
                          onFocusChange: (f) => setState(() => _nameFocused = f),
                          child: TextField(
                            controller: _nameController,
                            maxLength: 100,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. Daily Tech Updates',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Outfit',
                                color: colors.placeholder,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description Field
                  Container(
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _descFocused ? colors.primary : colors.border.withOpacity(0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'DESCRIPTION',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                color: colors.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${_descController.text.length}/500',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Outfit',
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Focus(
                          onFocusChange: (f) => setState(() => _descFocused = f),
                          child: TextField(
                            controller: _descController,
                            maxLength: 500,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Outfit',
                              color: colors.text,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tell people what your channel is about…',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Outfit',
                                color: colors.placeholder,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Channel Type Selector (Public vs Private)
                  Text(
                    'CHANNEL TYPE',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      color: colors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _channelType = 'public'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _channelType == 'public' ? colors.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _channelType == 'public'
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Public',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Outfit',
                                  fontWeight: _channelType == 'public' ? FontWeight.bold : FontWeight.normal,
                                  color: _channelType == 'public' ? colors.primary : colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _channelType = 'private'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _channelType == 'private' ? colors.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _channelType == 'private'
                                    ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Private',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Outfit',
                                  fontWeight: _channelType == 'private' ? FontWeight.bold : FontWeight.normal,
                                  color: _channelType == 'private' ? colors.primary : colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Username / Handle Field (if Public)
                  if (_channelType == 'public') ...[
                    Container(
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _usernameFocused ? colors.primary : colors.border.withOpacity(0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHANNEL HANDLE',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              color: colors.textTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '@',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Focus(
                                  onFocusChange: (f) => setState(() => _usernameFocused = f),
                                  child: TextField(
                                    controller: _usernameController,
                                    maxLength: 20,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontFamily: 'Outfit',
                                      color: colors.text,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'channel_handle',
                                      hintStyle: TextStyle(
                                        fontSize: 15,
                                        fontFamily: 'Outfit',
                                        color: colors.placeholder,
                                      ),
                                      border: InputBorder.none,
                                      counterText: '',
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: _onUsernameChanged,
                                  ),
                                ),
                              ),
                              if (_usernameStatus == 'checking')
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                                )
                              else if (_usernameStatus == 'available')
                                const Icon(Icons.check_circle, size: 18, color: Color(0xFF22C55E))
                              else if (_usernameStatus == 'taken')
                                const Icon(Icons.cancel, size: 18, color: Color(0xFFEF4444))
                              else if (_usernameStatus == 'invalid')
                                const Icon(Icons.error_outline, size: 18, color: Color(0xFFF59E0B)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _usernameStatus == 'available'
                            ? 'witalk.in/${_usernameController.text} is available'
                            : _usernameStatus == 'taken'
                                ? 'That handle is taken — try another'
                                : _usernameStatus == 'invalid'
                                    ? '5–20 lowercase letters, numbers, or underscores'
                                    : 'Choose a unique handle for your channel',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Outfit',
                          color: _usernameStatus == 'available'
                              ? const Color(0xFF22C55E)
                              : _usernameStatus == 'taken'
                                  ? const Color(0xFFEF4444)
                                  : _usernameStatus == 'invalid'
                                      ? const Color(0xFFF59E0B)
                                      : colors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Create Channel Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isFormValid && !_loading ? _handleCreate : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        disabledBackgroundColor: colors.primaryButtonDisabled,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'Create Channel',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
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
