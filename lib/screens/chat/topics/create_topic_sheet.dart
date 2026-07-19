import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/theme_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../api/dio_client.dart';
import '../../../api/app_endpoints.dart';
import '../../../services/chat_api_service.dart';

/// Bottom sheet for creating a new topic inside a group.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => CreateTopicSheet(
///     groupId: groupId,
///     onCreated: () { ... },
///   ),
/// );
/// ```
class CreateTopicSheet extends ConsumerStatefulWidget {
  final String groupId;
  final VoidCallback onCreated;

  const CreateTopicSheet({
    super.key,
    required this.groupId,
    required this.onCreated,
  });

  @override
  ConsumerState<CreateTopicSheet> createState() => _CreateTopicSheetState();
}

class _CreateTopicSheetState extends ConsumerState<CreateTopicSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _titleFocus = FocusNode();

  String _type = 'discussion'; // 'discussion' | 'poll' | 'announcement'
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus title when sheet opens
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _titleFocus.requestFocus());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _titleFocus.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty && !_submitting;

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      _titleFocus.requestFocus();
      return;
    }

    List<String>? options;
    if (_type == 'poll') {
      options = _pollOptions
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A poll needs at least 2 options')));
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await chatApiService.createGroupTopic(
        groupId: widget.groupId,
        title: title,
        content: content,
        type: _type,
        options: options,
      );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create topic. Try again.')));
        setState(() => _submitting = false);
      }
    }
  }

  void _addPollOption() {
    if (_pollOptions.length >= 6) return;
    setState(() => _pollOptions.add(TextEditingController()));
  }

  void _removePollOption(int index) {
    if (_pollOptions.length <= 2) return;
    setState(() {
      _pollOptions[index].dispose();
      _pollOptions.removeAt(index);
    });
  }

  InputDecoration _inputDec(ThemeColors c, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.placeholder, fontFamily: 'Outfit'),
        filled: true,
        fillColor: c.cardBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.bottomSheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Topic',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 19,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(
                          color: c.textSecondary, fontFamily: 'Outfit')),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Type selector ──
            Text(
              'Type',
              style: TextStyle(
                color: c.textSecondary,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeChip(
                  label: 'Discussion',
                  icon: Icons.forum_outlined,
                  selected: _type == 'discussion',
                  c: c,
                  onTap: () => setState(() => _type = 'discussion'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Poll',
                  icon: Icons.poll_outlined,
                  selected: _type == 'poll',
                  c: c,
                  onTap: () => setState(() => _type = 'poll'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Announcement',
                  icon: Icons.campaign_outlined,
                  selected: _type == 'announcement',
                  c: c,
                  onTap: () => setState(() => _type = 'announcement'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Title ──
            Text(
              'Title *',
              style: TextStyle(
                color: c.textSecondary,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  color: c.text, fontFamily: 'Outfit', fontSize: 15),
              decoration: _inputDec(c, 'Enter topic title'),
            ),
            const SizedBox(height: 14),

            // ── Content / Description ──
            Text(
              'Description',
              style: TextStyle(
                color: c.textSecondary,
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _contentCtrl,
              minLines: 3,
              maxLines: 6,
              style: TextStyle(
                  color: c.text, fontFamily: 'Outfit', fontSize: 14),
              decoration: _inputDec(c, 'Add more context (optional)'),
            ),

            // ── Poll options ──
            if (_type == 'poll') ...[
              const SizedBox(height: 16),
              Text(
                'Poll Options',
                style: TextStyle(
                  color: c.textSecondary,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_pollOptions.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.border),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                                color: c.textTertiary,
                                fontFamily: 'Outfit',
                                fontSize: 11),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _pollOptions[i],
                          style: TextStyle(
                              color: c.text,
                              fontFamily: 'Outfit',
                              fontSize: 14),
                          decoration:
                              _inputDec(c, 'Option ${i + 1}'),
                        ),
                      ),
                      if (_pollOptions.length > 2)
                        GestureDetector(
                          onTap: () => _removePollOption(i),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.close,
                                size: 20, color: c.error),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              if (_pollOptions.length < 6)
                GestureDetector(
                  onTap: _addPollOption,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: c.primary.withOpacity(0.5),
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: c.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Add Option',
                          style: TextStyle(
                            color: c.primary,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),

            // ── Submit ──
            ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primaryButton,
                disabledBackgroundColor: c.primaryButtonDisabled,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Create Topic',
                          style: TextStyle(
                            color: _canSubmit
                                ? Colors.white
                                : Colors.white70,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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

// ── Type chip ─────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ThemeColors c;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.primary : c.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: selected ? c.primary : c.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : c.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : c.textSecondary,
                  fontFamily: 'Outfit',
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
