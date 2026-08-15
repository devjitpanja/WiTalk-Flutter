import 'package:flutter/material.dart';
import '../../api/channel_api.dart';
import '../../theme/theme_colors.dart';

const _reportColor = Color(0xFFE74C3C);

const _kCategories = [
  {'value': 'spam', 'label': 'Spam', 'icon': Icons.block_rounded, 'color': Color(0xFFFF6B6B)},
  {'value': 'hate_speech', 'label': 'Hate Speech', 'icon': Icons.sentiment_very_dissatisfied_rounded, 'color': Color(0xFFE74C3C)},
  {'value': 'violence', 'label': 'Violence', 'icon': Icons.warning_rounded, 'color': Color(0xFFE67E22)},
  {'value': 'inappropriate_content', 'label': 'Inappropriate', 'icon': Icons.report_rounded, 'color': Color(0xFFF39C12)},
  {'value': 'scam', 'label': 'Scam / Fraud', 'icon': Icons.money_off_rounded, 'color': Color(0xFF8E44AD)},
  {'value': 'terrorism', 'label': 'Terrorism', 'icon': Icons.gpp_bad_rounded, 'color': Color(0xFFC0392B)},
  {'value': 'child_safety', 'label': 'Child Safety', 'icon': Icons.child_care_rounded, 'color': Color(0xFFD35400)},
  {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Color(0xFF7F8C8D)},
];

Future<void> showChannelReportSheet(
  BuildContext context, {
  required String channelId,
  required String channelName,
  required VoidCallback onSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChannelReportSheet(
      channelId: channelId,
      channelName: channelName,
      onSuccess: onSuccess,
    ),
  );
}

class _ChannelReportSheet extends StatefulWidget {
  final String channelId;
  final String channelName;
  final VoidCallback onSuccess;

  const _ChannelReportSheet({
    required this.channelId,
    required this.channelName,
    required this.onSuccess,
  });

  @override
  State<_ChannelReportSheet> createState() => _ChannelReportSheetState();
}

class _ChannelReportSheetState extends State<_ChannelReportSheet> {
  String? _selected;
  final _otherCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selected != null &&
      (_selected != 'other' || _otherCtrl.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() { _submitting = true; _error = null; });
    try {
      await ChannelApi.reportChannel(
        widget.channelId,
        _selected!,
        _selected == 'other' ? _otherCtrl.text.trim() : null,
      );
      if (mounted) setState(() => _submitted = true);
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      final isDuplicate = e.toString().contains('409') || e.toString().contains('already reported');
      setState(() {
        _submitting = false;
        _error = isDuplicate ? 'You have already reported this.' : 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 24),
      child: SingleChildScrollView(
        child: _submitted ? _buildSuccess(c) : _buildContent(c),
      ),
    );
  }

  Widget _buildSuccess(ThemeColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            color: c.success.withValues(alpha: 0.13),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, size: 48, color: c.success),
        ),
        const SizedBox(height: 16),
        Text('Report Submitted', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 8),
        Text(
          'Thank you. Our team will review this report shortly.',
          style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.45),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildContent(ThemeColors c) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Handle
      Center(
        child: Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(color: c.textTertiary.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
        ),
      ),
      // Header
      Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _reportColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.flag_rounded, size: 22, color: _reportColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Report Channel', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
          Text(widget.channelName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ])),
      ]),
      const SizedBox(height: 16),
      Container(height: 0.5, color: c.border),
      const SizedBox(height: 16),
      Text('SELECT A REASON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 0.8, color: c.textTertiary)),
      const SizedBox(height: 12),
      // Category grid
      Wrap(
        spacing: 10, runSpacing: 10,
        children: _kCategories.map((cat) {
          final value = cat['value'] as String;
          final label = cat['label'] as String;
          final icon = cat['icon'] as IconData;
          final color = cat['color'] as Color;
          final selected = _selected == value;
          return GestureDetector(
            onTap: () => setState(() => _selected = value),
            child: Container(
              width: (MediaQuery.of(context).size.width - 42) / 2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.1) : c.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? color : c.border, width: 1.5),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: 0.15) : c.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: selected ? color : c.textTertiary),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(label, maxLines: 2,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: selected ? color : c.text, height: 1.3))),
              ]),
            ),
          );
        }).toList(),
      ),
      // Other text input
      if (_selected == 'other') ...[
        const SizedBox(height: 14),
        TextField(
          controller: _otherCtrl,
          maxLines: 3,
          maxLength: 300,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 14, color: c.text),
          decoration: InputDecoration(
            hintText: 'Describe the issue…',
            hintStyle: TextStyle(color: c.textTertiary),
            filled: true,
            fillColor: c.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _reportColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
      // Error
      if (_error != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _reportColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _reportColor.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: _reportColor),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: _reportColor))),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      // Submit button
      SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: _canSubmit && !_submitting ? _submit : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _canSubmit ? _reportColor : c.border,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_submitting)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFFFFF)),
                )
              else ...[
                const Icon(Icons.flag_rounded, size: 18, color: Color(0xFFFFFFFF)),
                const SizedBox(width: 8),
                const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))),
              ],
            ]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Center(
        child: Text('False reports may result in account restrictions.',
            style: TextStyle(fontSize: 11, color: c.textTertiary)),
      ),
    ]);
  }
}
