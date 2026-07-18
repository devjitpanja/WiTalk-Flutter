import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

const _options = [
  ('everyone', 'Everyone', 'Anyone on WiTalk can send you a message', Icons.public),
  ('followers', 'Your Followers', 'Only people who follow you can message you', Icons.people),
  ('friends', 'Your Friends', 'Only mutual followers (friends) can message you', Icons.star),
  ('same_gender', 'Same Gender Only', 'Only people of the same gender as you can message you', Icons.wc),
  ('verified_only', 'Verified Users Only', 'Only verified users with a badge can message you', Icons.verified),
  ('no_one', 'No One', 'Nobody can start a new conversation with you', Icons.block),
];

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get optionBg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
}

class MessagePrivacyScreen extends ConsumerStatefulWidget {
  const MessagePrivacyScreen({super.key});
  @override
  ConsumerState<MessagePrivacyScreen> createState() => _MessagePrivacyScreenState();
}

class _MessagePrivacyScreenState extends ConsumerState<MessagePrivacyScreen> {
  String _selected = 'everyone';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.get('/v1/user/$uid/message-privacy');
      if (mounted && res.data['success'] == true) {
        setState(() => _selected = res.data['data']['messagePrivacy'] ?? 'everyone');
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _select(String value) async {
    if (value == _selected || _saving) return;
    final prev = _selected;
    setState(() { _selected = value; _saving = true; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      final res = await dioClient.put('/v1/user/$uid/message-privacy', data: {'messagePrivacy': value});
      if (res.data['success'] != true) throw Exception();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message privacy updated', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Color(0xFF34C759)));
    } catch (_) {
      if (mounted) { setState(() => _selected = prev); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update. Please try again.'), backgroundColor: Color(0xFFFF453A))); }
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [
          GestureDetector(onTap: () => context.pop(), child: Icon(Icons.arrow_back, color: t.text, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Text('Message Privacy', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text))),
          SizedBox(width: 24, child: _saving ? CircularProgressIndicator(strokeWidth: 2, color: t.primary) : null),
        ])),
        if (_loading)
          Expanded(child: Center(child: CircularProgressIndicator(color: t.primary)))
        else ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
            child: Column(children: [
              for (int i = 0; i < _options.length; i++) ...[
                if (i > 0) Container(height: 1, color: t.border),
                _optionRow(_options[i], t),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 14, color: t.textTertiary),
            const SizedBox(width: 6),
            Expanded(child: Text('This setting only affects new conversations. Existing chats are not affected.', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary, height: 1.5))),
          ])),
        ],
      ])),
    );
  }

  Widget _optionRow((String, String, String, IconData) opt, _T t) {
    final (value, label, desc, icon) = opt;
    final isSelected = _selected == value;
    return GestureDetector(
      onTap: _saving ? null : () => _select(value),
      child: Container(
        color: isSelected ? t.primary.withAlpha(0x0A) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: isSelected ? t.primary.withAlpha(0x20) : t.optionBg, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: isSelected ? t.primary : t.textTertiary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: isSelected ? t.primary : t.text, height: 1.2)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary, height: 1.4)),
          ])),
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? t.primary : t.border, width: 2)),
            child: isSelected ? Center(child: Container(width: 11, height: 11, decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle))) : null,
          ),
        ]),
      ),
    );
  }
}
