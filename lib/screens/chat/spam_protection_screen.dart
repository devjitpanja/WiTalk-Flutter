import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../api/dio_client.dart';
import '../../api/app_endpoints.dart';
import '../../services/chat_api_service.dart';

// ── Action enum ───────────────────────────────────────────────────────────────

enum _SpamAction { warn, mute, ban }

extension _SpamActionLabel on _SpamAction {
  String get label {
    switch (this) {
      case _SpamAction.warn: return 'Warn';
      case _SpamAction.mute: return 'Mute';
      case _SpamAction.ban:  return 'Ban';
    }
  }

  String get value {
    switch (this) {
      case _SpamAction.warn: return 'warn';
      case _SpamAction.mute: return 'mute';
      case _SpamAction.ban:  return 'ban';
    }
  }

  static _SpamAction fromString(String? s) {
    switch (s) {
      case 'mute': return _SpamAction.mute;
      case 'ban':  return _SpamAction.ban;
      default:     return _SpamAction.warn;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SpamProtectionScreen extends ConsumerStatefulWidget {
  final String groupId;

  const SpamProtectionScreen({super.key, required this.groupId});

  @override
  ConsumerState<SpamProtectionScreen> createState() =>
      _SpamProtectionScreenState();
}

class _SpamProtectionScreenState extends ConsumerState<SpamProtectionScreen> {
  bool _loading = true;
  bool _saving = false;

  // Settings state
  bool _enabled = false;
  int _maxMessagesPerMinute = 10;
  int _maxIdenticalMessages = 3;
  _SpamAction _action = _SpamAction.warn;
  List<String> _blockedWords = [];

  // Word filter input
  final _wordCtrl = TextEditingController();
  final _wordFocus = FocusNode();

  // Threshold controllers (bound to int fields)
  late TextEditingController _rateCtrl;
  late TextEditingController _identicalCtrl;

  @override
  void initState() {
    super.initState();
    _rateCtrl = TextEditingController(text: '$_maxMessagesPerMinute');
    _identicalCtrl =
        TextEditingController(text: '$_maxIdenticalMessages');
    _loadSettings();
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    _wordFocus.dispose();
    _rateCtrl.dispose();
    _identicalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final data =
          await chatApiService.getSpamProtectionSettings(widget.groupId);
      if (data != null && mounted) {
        final words = data['blocked_words'];
        setState(() {
          _enabled = data['enabled'] == true;
          _maxMessagesPerMinute =
              (data['max_messages_per_minute'] as num?)?.toInt() ?? 10;
          _maxIdenticalMessages =
              (data['max_identical_messages'] as num?)?.toInt() ?? 3;
          _action = _SpamActionLabel.fromString(data['action']?.toString());
          _blockedWords = words is List
              ? List<String>.from(words.map((w) => w.toString()))
              : [];
          _rateCtrl.text = '$_maxMessagesPerMinute';
          _identicalCtrl.text = '$_maxIdenticalMessages';
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    // Sync text fields → int
    final rate = int.tryParse(_rateCtrl.text.trim()) ?? _maxMessagesPerMinute;
    final identical =
        int.tryParse(_identicalCtrl.text.trim()) ?? _maxIdenticalMessages;
    setState(() {
      _maxMessagesPerMinute = rate.clamp(1, 300);
      _maxIdenticalMessages = identical.clamp(1, 50);
      _saving = true;
    });

    try {
      await chatApiService.updateSpamProtectionSettings(widget.groupId, {
        'enabled': _enabled,
        'max_messages_per_minute': _maxMessagesPerMinute,
        'max_identical_messages': _maxIdenticalMessages,
        'action': _action.value,
        'blocked_words': _blockedWords,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Settings saved',
              style:
                  TextStyle(fontFamily: 'Outfit', color: context.colors.text)),
          backgroundColor: context.colors.surface,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save settings')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addWord() {
    final word = _wordCtrl.text.trim().toLowerCase();
    if (word.isEmpty) return;
    if (_blockedWords.contains(word)) {
      _wordCtrl.clear();
      return;
    }
    setState(() {
      _blockedWords = [..._blockedWords, word];
      _wordCtrl.clear();
    });
    _wordFocus.requestFocus();
  }

  void _removeWord(String word) {
    setState(() => _blockedWords = _blockedWords.where((w) => w != word).toList());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
          'Spam Protection',
          style: TextStyle(
            color: c.text,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _loading ? null : _save,
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: _loading ? c.textTertiary : c.primary,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── Enable toggle ──
                _SectionCard(
                  c: c,
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: _enabled ? c.success : c.textTertiary,
                          size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spam Protection',
                              style: TextStyle(
                                color: c.text,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Automatically detect and act on spam',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontFamily: 'Outfit',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                        activeColor: c.primary,
                      ),
                    ],
                  ),
                ),

                if (_enabled) ...[
                  const SizedBox(height: 16),

                  // ── Thresholds ──
                  _SectionHeader(label: 'Thresholds', c: c),
                  const SizedBox(height: 8),
                  _SectionCard(
                    c: c,
                    child: Column(
                      children: [
                        _NumberRow(
                          label: 'Max messages per minute',
                          hint:
                              'How many messages a user can send per minute before being flagged',
                          ctrl: _rateCtrl,
                          c: c,
                          min: 1,
                          max: 300,
                        ),
                        Divider(color: c.border, height: 24),
                        _NumberRow(
                          label: 'Max identical messages',
                          hint:
                              'How many times the same text can be sent before triggering spam detection',
                          ctrl: _identicalCtrl,
                          c: c,
                          min: 1,
                          max: 50,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Action ──
                  _SectionHeader(label: 'Action on Detection', c: c),
                  const SizedBox(height: 8),
                  _SectionCard(
                    c: c,
                    child: Column(
                      children: _SpamAction.values.map((action) {
                        final selected = _action == action;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _action = action),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? c.primary
                                          : c.border,
                                      width: 2,
                                    ),
                                    color: selected
                                        ? c.primary
                                        : Colors.transparent,
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check,
                                          size: 13, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action.label,
                                        style: TextStyle(
                                          color: c.text,
                                          fontFamily: 'Outfit',
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        _actionDescription(action),
                                        style: TextStyle(
                                          color: c.textTertiary,
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
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Word filter ──
                  _SectionHeader(label: 'Word Filter', c: c),
                  const SizedBox(height: 4),
                  Text(
                    'Messages containing these words will be flagged.',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontFamily: 'Outfit',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SectionCard(
                    c: c,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _wordCtrl,
                                focusNode: _wordFocus,
                                style: TextStyle(
                                    color: c.text, fontFamily: 'Outfit'),
                                textCapitalization:
                                    TextCapitalization.none,
                                onSubmitted: (_) => _addWord(),
                                decoration: InputDecoration(
                                  hintText: 'Add blocked word',
                                  hintStyle: TextStyle(
                                      color: c.placeholder,
                                      fontFamily: 'Outfit'),
                                  filled: true,
                                  fillColor: c.background,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: c.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: c.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: c.primary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _addWord,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: c.primaryButton,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        // Chip list
                        if (_blockedWords.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _blockedWords
                                .map((word) => _WordChip(
                                      word: word,
                                      c: c,
                                      onRemove: () => _removeWord(word),
                                    ))
                                .toList(),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          Text(
                            'No blocked words added',
                            style: TextStyle(
                              color: c.textTertiary,
                              fontFamily: 'Outfit',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
    );
  }

  String _actionDescription(_SpamAction action) {
    switch (action) {
      case _SpamAction.warn:
        return 'Send the user a warning message';
      case _SpamAction.mute:
        return 'Temporarily mute the user for 10 minutes';
      case _SpamAction.ban:
        return 'Remove the user from the group';
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemeColors c;
  const _SectionHeader({required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: c.textTertiary,
        fontFamily: 'Outfit',
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final ThemeColors c;
  final Widget child;
  const _SectionCard({required this.c, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _NumberRow extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  final ThemeColors c;
  final int min;
  final int max;

  const _NumberRow({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.c,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: TextStyle(
                  color: c.textTertiary,
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final ThemeColors c;
  final VoidCallback onRemove;
  const _WordChip({required this.word, required this.c, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.error.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            style: TextStyle(
              color: c.error,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: c.error),
          ),
        ],
      ),
    );
  }
}
