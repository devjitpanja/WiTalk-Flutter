import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/channel_api.dart';
import '../../api/dio_client.dart';
import '../../theme/theme_colors.dart';

class EditChannelScreen extends StatefulWidget {
  final String channelId;
  final Map<String, dynamic>? initialChannel;

  const EditChannelScreen({
    super.key,
    required this.channelId,
    this.initialChannel,
  });

  @override
  State<EditChannelScreen> createState() => _EditChannelScreenState();
}

class _EditChannelScreenState extends State<EditChannelScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _usernameController;

  Timer? _usernameTimer;

  Map<String, dynamic>? _channel;
  bool _loading = true;
  bool _saving = false;
  XFile? _newPic;
  String _channelType = 'public';
  String? _usernameStatus;

  final RegExp _usernameRegex = RegExp(r'^[a-z0-9_]{3,30}$');

  @override
  void initState() {
    super.initState();
    _channel = widget.initialChannel;
    _nameController = TextEditingController(text: _channel?['name'] ?? '');
    _descController = TextEditingController(text: _channel?['description'] ?? '');
    _usernameController = TextEditingController(text: _channel?['username'] ?? '');
    _channelType = _channel?['channel_type'] ?? 'public';
    _usernameStatus = _channelType == 'public' && (_channel?['username'] ?? '').isNotEmpty
        ? 'available'
        : null;

    if (_channel == null) {
      _fetchChannel();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _usernameController.dispose();
    _usernameTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchChannel() async {
    try {
      final res = await ChannelApi.getById(widget.channelId);
      final data = res.data?['channel'];
      if (data != null && mounted) {
        setState(() {
          _channel = data;
          _nameController.text = data['name'] ?? '';
          _descController.text = data['description'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _channelType = data['channel_type'] ?? 'public';
          _usernameStatus = _channelType == 'public' && (_channel?['username'] ?? '').isNotEmpty
              ? 'available'
              : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isOwner => _channel?['my_role'] == 'owner';

  bool get _isDirty {
    if (_newPic != null) return true;
    if (_nameController.text.trim() != (_channel?['name'] ?? '').trim()) return true;
    if (_descController.text.trim() != (_channel?['description'] ?? '').trim()) return true;
    if (_channelType != (_channel?['channel_type'] ?? 'public')) return true;
    if (_channelType == 'public' &&
        _usernameController.text.trim() != (_channel?['username'] ?? '')) return true;
    return false;
  }

  bool get _canSave =>
      _isDirty &&
      _nameController.text.trim().length >= 3 &&
      !_saving &&
      (_channelType != 'public' ||
          _usernameStatus == 'available' ||
          _usernameController.text.trim() == (_channel?['username'] ?? ''));

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
    if (sanitized == _channel?['username']) {
      setState(() => _usernameStatus = 'available');
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
        setState(() => _newPic = picked);
      }
    } catch (_) {
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

  Future<void> _handleSave() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final userId = await _storage.read(key: 'uid');
      final Map<String, dynamic> payload = {};

      if (_nameController.text.trim() != (_channel?['name'] ?? '')) {
        payload['name'] = _nameController.text.trim();
      }
      if (_descController.text.trim() != (_channel?['description'] ?? '')) {
        payload['description'] = _descController.text.trim();
      }
      if (_channelType != (_channel?['channel_type'] ?? 'public')) {
        payload['channel_type'] = _channelType;
      }
      if (_channelType == 'public' &&
          _usernameController.text.trim() != (_channel?['username'] ?? '')) {
        payload['username'] = _usernameController.text.trim();
      }

      if (_newPic != null && userId != null) {
        final iconUrl = await _uploadImage(_newPic!, userId);
        if (iconUrl != null) {
          payload['icon'] = iconUrl;
        } else {
          _showAlert('Upload Failed', 'Could not upload channel photo');
          setState(() => _saving = false);
          return;
        }
      }

      await ChannelApi.update(widget.channelId, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Channel updated successfully')),
        );
        context.pop(true);
      }
    } catch (err) {
      _showAlert('Error', 'Could not save changes. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Delete Channel?',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: colors.text)),
        content: Text(
          'Are you sure you want to delete this channel? All messages and subscribers will be permanently removed.',
          style: TextStyle(fontFamily: 'Outfit', color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChannelApi.deleteChannel(widget.channelId);
        if (mounted) {
          context.go('/channels');
        }
      } catch (_) {
        _showAlert('Error', 'Could not delete channel.');
      }
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_loading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    final iconUrl = _newPic?.path ?? _channel?['icon']?.toString();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Channel',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: colors.text),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                  )
                : Icon(Icons.check, color: _canSave ? colors.primary : colors.textTertiary),
            onPressed: _canSave ? _handleSave : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Photo Section
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImagePickerModal,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            image: iconUrl != null && iconUrl.isNotEmpty
                                ? DecorationImage(
                                    image: iconUrl.startsWith('/') || iconUrl.startsWith('file://')
                                        ? NetworkImage(iconUrl)
                                        : NetworkImage(iconUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: iconUrl == null || iconUrl.isEmpty
                              ? Text(
                                  (_nameController.text.isNotEmpty ? _nameController.text[0] : 'C')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surface,
                            border: Border.all(color: colors.border),
                          ),
                          child: Icon(Icons.camera_alt, size: 16, color: colors.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showImagePickerModal,
                    child: Text(
                      'Set New Photo',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name & Description Card
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.title, size: 18, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Channel Name',
                                style: TextStyle(
                                    fontSize: 12, fontFamily: 'Outfit', color: colors.textSecondary)),
                            TextField(
                              controller: _nameController,
                              style: TextStyle(
                                  fontSize: 15, fontFamily: 'Outfit', color: colors.text),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.only(top: 4),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: colors.border.withOpacity(0.3)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notes, size: 18, color: Color(0xFF8B5CF6)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Description',
                                style: TextStyle(
                                    fontSize: 12, fontFamily: 'Outfit', color: colors.textSecondary)),
                            TextField(
                              controller: _descController,
                              maxLines: 3,
                              style: TextStyle(
                                  fontSize: 14, fontFamily: 'Outfit', color: colors.text),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.only(top: 4),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Channel Type Card
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.public, color: colors.primary),
                    title: Text('Public', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
                    subtitle: Text('Anyone can subscribe · witalk.in/username',
                        style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: colors.textSecondary)),
                    trailing: Radio<String>(
                      value: 'public',
                      groupValue: _channelType,
                      onChanged: _isOwner ? (v) => setState(() => _channelType = v!) : null,
                    ),
                  ),
                  Divider(height: 1, color: colors.border.withOpacity(0.3)),
                  ListTile(
                    leading: const Icon(Icons.lock, color: Colors.red),
                    title: Text('Private', style: TextStyle(fontFamily: 'Outfit', color: colors.text)),
                    subtitle: Text('Invite link only · revocable anytime',
                        style: TextStyle(fontSize: 12, fontFamily: 'Outfit', color: colors.textSecondary)),
                    trailing: Radio<String>(
                      value: 'private',
                      groupValue: _channelType,
                      onChanged: _isOwner ? (v) => setState(() => _channelType = v!) : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Delete Channel Button (Owner only)
            if (_isOwner)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Delete Channel',
                      style: TextStyle(fontFamily: 'Outfit', color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
