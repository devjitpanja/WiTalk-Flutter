import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

const _deleteReasons = [
  ('not_useful', "App isn't useful for me"),
  ('privacy_concern', 'Privacy concerns'),
  ('too_many_notifications', 'Too many notifications'),
  ('found_alternative', 'Found a better alternative'),
  ('temporary_break', 'Taking a temporary break'),
  ('other', 'Other reason'),
];
const _countdownSecs = 10;

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get primary => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  Color get noticeBg => dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  Color get chipInactive => dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  Color get delBtnDisabledBg => dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  Color get delBtnDisabledText => dark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
}

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  Map<String, dynamic>? _userData;
  bool _loading = true;

  String? _selectedReason;
  String _customReason = '';
  int _countdown = _countdownSecs;
  bool _countdownDone = false;
  bool _deleting = false;
  Timer? _timer;
  final _ctrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) return;
      final res = await dioClient.get('/v1/user/$uid');
      if (mounted) setState(() => _userData = Map<String, dynamic>.from(res.data['data'] as Map));
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _openDeleteSheet() {
    setState(() { _selectedReason = null; _customReason = ''; _ctrl.clear(); _countdown = _countdownSecs; _countdownDone = false; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown <= 1) { t.cancel(); _countdown = 0; _countdownDone = true; }
        else _countdown--;
      });
    });
    final isDark = ref.read(themeProvider);
    final t = _T(isDark);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DeleteSheet(parent: this, t: t),
    ).whenComplete(() { _timer?.cancel(); if (mounted) setState(() => _deleting = false); });
  }

  bool get _canDelete => _countdownDone && _selectedReason != null && (_selectedReason != 'other' || _customReason.trim().length >= 5);

  Future<void> _confirmDelete() async {
    if (!_canDelete || _deleting) return;
    setState(() => _deleting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('You must be signed in. Please restart the app.');
      final token = await user.getIdToken(true);
      await dioClient.post('/v1/user/account/delete', data: {
        'firebaseIdToken': token,
        'reason': _selectedReason,
        if (_selectedReason == 'other') 'customReason': _customReason.trim(),
      });
      if (mounted) {
        Navigator.of(context).pop();
        await Future.delayed(const Duration(milliseconds: 350));
        ref.read(authProvider.notifier).signOut();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().contains('signed in') ? e.toString() : 'Failed to delete account. Try again.'),
          backgroundColor: const Color(0xFFFF453A),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    if (_loading) return Scaffold(backgroundColor: t.bg, body: Center(child: CircularProgressIndicator(color: t.primary)));

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [
          GestureDetector(onTap: () => context.pop(), child: Icon(Icons.arrow_back, color: t.text, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Text('Account', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text))),
        ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('ACCOUNT INFORMATION', t),
          _card(t, [
            _infoRow(Icons.person, 'Full Name', _userData?['name'], t),
            _infoRow(Icons.alternate_email, 'Username', '@${_userData?['username'] ?? ''}', t),
            _infoRow(Icons.email, 'Email Address', _userData?['email'], t),
            _infoRow(Icons.fingerprint, 'User ID', _userData?['id']?.toString(), t),
            Padding(padding: const EdgeInsets.fromLTRB(14, 13, 14, 13), child: Row(children: [
              _iconBox(Icons.verified_user, t),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Account Status', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Active', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: t.text)),
                ]),
              ])),
            ])),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: t.noticeBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.border, width: 0.5)),
            child: Row(children: [
              Icon(Icons.lock, size: 15, color: t.textTertiary),
              const SizedBox(width: 6),
              Expanded(child: Text('Email address cannot be changed as it is linked to your sign-in method.', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 28),
          _sectionLabel('DANGER ZONE', t),
          Container(
            decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x33FF453A))),
            child: GestureDetector(onTap: _openDeleteSheet, child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 14), child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0x18FF453A), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_forever, size: 18, color: Color(0xFFFF453A))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Delete Account', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFFFF453A))),
                const SizedBox(height: 2),
                Text('Permanently remove your account and all data', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
              ])),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFFF453A)),
            ]))),
          ),
        ]))),
      ])),
    );
  }

  Widget _sectionLabel(String s, _T t) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 4, top: 12), child: Text(s, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 11, color: t.textTertiary, letterSpacing: 1.3)));

  Widget _card(_T t, List<Widget> children) => Container(decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)), child: Column(children: children));

  Widget _iconBox(IconData icon, _T t) => Container(width: 36, height: 36, decoration: BoxDecoration(color: t.primary.withAlpha(0x14), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: t.primary));

  Widget _infoRow(IconData icon, String label, String? value, _T t) => Container(
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: 0.5))),
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
    child: Row(children: [
      _iconBox(icon, t),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: t.textTertiary)),
        const SizedBox(height: 2),
        Text(value ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: t.text)),
      ])),
    ]),
  );
}

class _DeleteSheet extends ConsumerStatefulWidget {
  final _AccountScreenState parent;
  final _T t;
  const _DeleteSheet({required this.parent, required this.t});
  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  @override
  Widget build(BuildContext context) {
    final p = widget.parent;
    final t = widget.t;
    final btmPad = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, btmPad),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: t.textTertiary, borderRadius: BorderRadius.circular(2)))),
        Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0x18FF453A), shape: BoxShape.circle), child: const Icon(Icons.warning, size: 26, color: Color(0xFFFF453A))),
        const SizedBox(height: 12),
        Text('Delete Account', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: t.text)),
        const SizedBox(height: 6),
        Text.rich(TextSpan(
          text: 'This action is ',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textTertiary, height: 1.5),
          children: const [
            TextSpan(text: 'permanent and irreversible.', style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.w700)),
            TextSpan(text: '\nAll your posts, messages, and data will be gone forever.'),
          ],
        ), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Row(children: [
          Text('Why are you deleting your account? ', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: t.text)),
          const Text('*', style: TextStyle(color: Color(0xFFFF453A))),
        ]),
        const SizedBox(height: 10),
        for (final (key, label) in _deleteReasons)
          GestureDetector(
            onTap: () { p.setState(() => p._selectedReason = key); setState(() {}); },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p._selectedReason == key ? const Color(0x18FF453A) : t.chipInactive,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p._selectedReason == key ? const Color(0xFFFF453A) : t.border),
              ),
              child: Row(children: [
                Icon(p._selectedReason == key ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 15, color: p._selectedReason == key ? const Color(0xFFFF453A) : t.textTertiary),
                const SizedBox(width: 5),
                Expanded(child: Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: p._selectedReason == key ? const Color(0xFFFF453A) : t.text))),
              ]),
            ),
          ),
        if (p._selectedReason == 'other') ...[
          const SizedBox(height: 6),
          TextField(
            controller: p._ctrl,
            maxLength: 300,
            maxLines: 3,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.text),
            onChanged: (v) { p.setState(() => p._customReason = v); setState(() {}); },
            decoration: InputDecoration(
              hintText: 'Tell us more (min 5 chars)…',
              hintStyle: TextStyle(color: t.textTertiary, fontFamily: 'Outfit'),
              counterStyle: TextStyle(color: t.textTertiary),
              filled: true, fillColor: t.chipInactive,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: Color(0xFFFF453A))),
            ),
          ),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () async { await p._confirmDelete(); if (mounted) setState(() {}); },
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(color: p._canDelete ? const Color(0xFFFF453A) : t.delBtnDisabledBg, borderRadius: BorderRadius.circular(14)),
            child: p._deleting
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : !p._countdownDone
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.timer, size: 18, color: t.delBtnDisabledText),
                        const SizedBox(width: 8),
                        Text('Wait ${p._countdown}s before deleting', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15, color: t.delBtnDisabledText)),
                      ])
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.delete_forever, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Delete My Account', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                      ]),
          ),
        ),
        GestureDetector(
          onTap: p._deleting ? null : () => Navigator.of(context).pop(),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Center(child: Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14, color: t.textTertiary)))),
        ),
      ]),
    );
  }
}
