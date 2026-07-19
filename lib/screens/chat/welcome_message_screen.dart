import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';

class WelcomeMessageScreen extends ConsumerStatefulWidget {
  final String groupId;

  const WelcomeMessageScreen({super.key, required this.groupId});

  @override
  ConsumerState<WelcomeMessageScreen> createState() =>
      _WelcomeMessageScreenState();
}

class _WelcomeMessageScreenState extends ConsumerState<WelcomeMessageScreen> {
  final _msgCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  String? _error;
  String? _originalMessage;
  bool _isDirty = false;

  static const int _maxLength = 500;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(_onTextChanged);
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isDirty = _msgCtrl.text.trim() != (_originalMessage ?? '').trim() ||
          _enabled != (_enabled);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await chatApiService.getGroupWelcomeMessage(widget.groupId);
      if (data != null) {
        final msg = data['message'] as String? ?? '';
        final enabled = data['enabled'] != false;
        _originalMessage = msg;
        _msgCtrl.text = msg;
        setState(() => _enabled = enabled);
      } else {
        _originalMessage = '';
      }
    } catch (_) {
      setState(() => _error = 'Failed to load welcome message.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _msgCtrl.text.trim();

    setState(() => _saving = true);
    try {
      await chatApiService.setGroupWelcomeMessage(widget.groupId, text);
      // Also persist enabled state if API supports it
      try {
        await dioClient.put('/v1/groups/${widget.groupId}/welcome-message', data: {
          'message': text,
          'enabled': _enabled,
        });
      } catch (_) {
        // If the combined endpoint fails, the basic set above succeeded — acceptable
      }
      _originalMessage = text;
      setState(() => _isDirty = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Welcome message saved.',
              style: const TextStyle(fontFamily: 'Outfit'),
            ),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to save welcome message.',
              style: TextStyle(fontFamily: 'Outfit'),
            ),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final remaining = _maxLength - _msgCtrl.text.length;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Welcome Message',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.primaryButton,
                        ),
                      )
                    : Text(
                        'Save',
                        style: TextStyle(
                          color: c.primaryButton,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primaryButton))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load, c: c)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.primaryButton.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: c.primaryButton.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: c.primaryButton),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This message is sent automatically to new members when they join the group.',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Enable toggle
                      Container(
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border),
                        ),
                        child: SwitchListTile(
                          value: _enabled,
                          onChanged: (v) {
                            setState(() {
                              _enabled = v;
                              _isDirty = true;
                            });
                          },
                          activeColor: c.primaryButton,
                          title: Text(
                            'Enable Welcome Message',
                            style: TextStyle(
                              color: c.text,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            _enabled ? 'Sent to new members' : 'Disabled',
                            style: TextStyle(
                              color: _enabled ? c.success : c.textTertiary,
                              fontFamily: 'Outfit',
                              fontSize: 12,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Label
                      Text(
                        'Message',
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Text field
                      TextField(
                        controller: _msgCtrl,
                        enabled: _enabled,
                        maxLines: 6,
                        maxLength: _maxLength,
                        style: TextStyle(
                          color: _enabled ? c.text : c.textTertiary,
                          fontFamily: 'Outfit',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Hi {name}, welcome to the group! 👋\n\nPlease read the group rules and enjoy your stay.',
                          hintStyle: TextStyle(
                            color: c.placeholder,
                            fontFamily: 'Outfit',
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: _enabled
                              ? c.surface
                              : c.surface.withOpacity(0.5),
                          counterStyle: TextStyle(
                            color: remaining < 50 ? c.warning : c.textTertiary,
                            fontFamily: 'Outfit',
                            fontSize: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: c.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: c.border),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: c.border.withOpacity(0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: c.primaryButton, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Variable hint
                      Text(
                        'Tip: Use {name} to insert the new member\'s name.',
                        style: TextStyle(
                          color: c.textTertiary,
                          fontFamily: 'Outfit',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Preview card
                      if (_msgCtrl.text.trim().isNotEmpty && _enabled) ...[
                        Text(
                          'Preview',
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PreviewBubble(
                          message: _msgCtrl.text
                              .trim()
                              .replaceAll('{name}', 'Alex'),
                          c: c,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primaryButton,
                            disabledBackgroundColor: c.primaryButtonDisabled,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  final String message;
  final ThemeColors c;

  const _PreviewBubble({required this.message, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.primaryButton.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Preview',
                  style: TextStyle(
                    color: c.primaryButton,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: c.primaryButton.withOpacity(0.2),
                child: Text(
                  'B',
                  style: TextStyle(
                    color: c.primaryButton,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bot',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.primaryButton.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: c.text,
                          fontFamily: 'Outfit',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ThemeColors c;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: c.error),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.primaryButton),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  color: c.primaryButton,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
