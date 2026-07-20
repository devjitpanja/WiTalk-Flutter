import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';
import '../../services/chat_api_service.dart';

const _defaultTemplate = 'Welcome to {group_name}, {name}! We\'re glad to have you here.';
const _maxLength = 500;

class WelcomeMessageScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? groupName;
  final bool isPublic;

  const WelcomeMessageScreen({
    super.key,
    required this.groupId,
    this.groupName,
    this.isPublic = false,
  });

  @override
  ConsumerState<WelcomeMessageScreen> createState() => _WelcomeMessageScreenState();
}

class _WelcomeMessageScreenState extends ConsumerState<WelcomeMessageScreen> {
  final _msgCtrl = TextEditingController();
  final _msgFocus = FocusNode();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool _hasChanges = false;
  String? _error;

  String _originalTemplate = _defaultTemplate;
  bool _originalEnabled = false;

  // Track cursor position for field insertion
  int _cursorPos = 0;

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
    _msgFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final changed = _msgCtrl.text != _originalTemplate || _enabled != _originalEnabled;
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await chatApiService.getGroupWelcomeMessage(widget.groupId);
      if (data != null) {
        final msg = data['message'] as String? ?? _defaultTemplate;
        final enabled = data['enabled'] != false;
        _originalTemplate = msg;
        _originalEnabled = enabled;
        _msgCtrl.text = msg;
        if (mounted) setState(() => _enabled = enabled);
      } else {
        _msgCtrl.text = _defaultTemplate;
        _originalTemplate = _defaultTemplate;
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load welcome message.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _insertField(String field) {
    final pos = _cursorPos.clamp(0, _msgCtrl.text.length);
    final current = _msgCtrl.text;
    final newText = current.substring(0, pos) + field + current.substring(pos);
    if (newText.length > _maxLength) return;
    _msgCtrl.text = newText;
    final newPos = pos + field.length;
    _msgCtrl.selection = TextSelection.collapsed(offset: newPos);
    _cursorPos = newPos;
    _msgFocus.requestFocus();
  }

  void _reset() {
    _msgCtrl.text = _defaultTemplate;
    _msgCtrl.selection = TextSelection.collapsed(offset: _defaultTemplate.length);
    _cursorPos = _defaultTemplate.length;
    final changed = _msgCtrl.text != _originalTemplate || _enabled != _originalEnabled;
    setState(() => _hasChanges = changed);
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _msgCtrl.text.trim();
    setState(() => _saving = true);
    try {
      // Use updateWelcomeMessageSettings if available, else fall back
      await chatApiService.setGroupWelcomeMessage(widget.groupId, text);
      // Try the full endpoint that includes enabled flag
      try {
        await chatApiService.updateGroupPermissions(widget.groupId, {
          'welcome_message_enabled': _enabled ? 1 : 0,
          'welcome_message_template': text.isEmpty ? null : text,
        });
      } catch (_) {
        // Fallback succeeded above
      }
      _originalTemplate = text;
      _originalEnabled = _enabled;
      if (mounted) setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome message settings updated successfully', style: TextStyle(fontFamily: 'Outfit')),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings. Please try again.', style: TextStyle(fontFamily: 'Outfit')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _label => widget.isPublic ? 'Community' : 'Group';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              'Welcome message',
              style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18),
            ),
            if (widget.groupName != null)
              Text(
                widget.groupName!,
                style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          const SizedBox(width: 40),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? _buildError(c)
              : _buildBody(c),
    );
  }

  Widget _buildBody(ThemeColors c) {
    final previewMessage = _msgCtrl.text
        .replaceAll('{name}', '@john_doe')
        .replaceAll('{group_name}', widget.groupName ?? 'My Group');

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          // ── Enable toggle ──────────────────────────────────────────────────
          Container(
            color: c.surface,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_people_outlined,
                  size: 24,
                  color: _enabled ? const Color(0xFF10B981) : c.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable welcome message',
                        style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Automatically send a message when new members join',
                        style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (v) {
                    setState(() {
                      _enabled = v;
                      _hasChanges = _msgCtrl.text != _originalTemplate || v != _originalEnabled;
                    });
                  },
                  activeColor: Colors.black,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE5E5EA),
                ),
              ],
            ),
          ),

          // ── Template editor ────────────────────────────────────────────────
          Container(
            color: c.surface,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message template',
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use dynamic fields to personalize the welcome message.\n{name} will insert @username mention of the new member.',
                  style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),

                // Dynamic field buttons
                Row(
                  children: [
                    _FieldButton(
                      c: c,
                      icon: Icons.person_outlined,
                      label: '{name}',
                      onTap: () => _insertField('{name}'),
                    ),
                    const SizedBox(width: 10),
                    _FieldButton(
                      c: c,
                      icon: Icons.group_outlined,
                      label: '{group_name}',
                      onTap: () => _insertField('{group_name}'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Template input
                TextField(
                  controller: _msgCtrl,
                  focusNode: _msgFocus,
                  maxLines: null,
                  maxLength: _maxLength,
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 15),
                  onTap: () {
                    _cursorPos = _msgCtrl.selection.extentOffset;
                  },
                  onChanged: (_) {
                    _cursorPos = _msgCtrl.selection.extentOffset;
                  },
                  decoration: InputDecoration(
                    hintText: 'Type your welcome message here...',
                    hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
                    filled: true,
                    fillColor: c.background,
                    counterStyle: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 4),

                // Reset to default
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _reset,
                    child: Text(
                      'Reset to default',
                      style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Preview ────────────────────────────────────────────────────────
          Container(
            color: c.surface,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: TextStyle(color: c.text, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.chat_bubble_outlined, size: 16, color: c.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Message preview',
                            style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        previewMessage.isEmpty ? '(empty)' : previewMessage,
                        style: TextStyle(color: c.text, fontFamily: 'Outfit', fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This message will be sent from your account when a new member joins',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Info note ──────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: c.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The welcome message is sent as a regular chat message from the ${_label.toLowerCase()} owner\'s account. '
                    'Use {name} to @mention the new member and {group_name} for the ${_label.toLowerCase()} name.',
                    style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          // ── Save button (only when changed) ────────────────────────────────
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.black.withOpacity(0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildError(ThemeColors c) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 48, color: c.error),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: c.textSecondary, fontFamily: 'Outfit', fontSize: 14)),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _load,
          child: Text('Retry', style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _FieldButton extends StatelessWidget {
  final ThemeColors c;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FieldButton({
    required this.c,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: c.primary, fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
