import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../api/dio_client.dart';
import '../../providers/theme_provider.dart';

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
  Color get skBase => dark ? const Color(0xFF1a1f2e) : const Color(0xFFE1E9EE);
  Color get skHi => dark ? const Color(0xFF242938) : const Color(0xFFF2F8FC);
  Color get walletBtnBg => const Color(0xFF10B981);
  Color get walletBtnBorder => const Color(0xFF8E8E93);
}

// ─── Status helpers ───────────────────────────────────────────────────────────
Color _statusColor(String? status) {
  switch (status) {
    case 'completed': return const Color(0xFF34C759);
    case 'verified':  return const Color(0xFF007AFF);
    case 'pending':   return const Color(0xFFFF9F0A);
    case 'invalid':
    case 'fraud_suspected': return const Color(0xFFFF3B30);
    default: return const Color(0xFF8E8E93);
  }
}

String _statusLabel(String? status, bool bonusAwarded) {
  if (status == 'verified' && !bonusAwarded) return 'Pending Reward';
  switch (status) {
    case 'completed':       return 'Completed';
    case 'verified':        return 'Rewarded';
    case 'pending':         return 'Pending';
    case 'invalid':         return 'Invalid';
    case 'fraud_suspected': return 'Fraud Detected';
    default: return status ?? '';
  }
}

int _daysRemaining(String? referredAt) {
  if (referredAt == null) return 0;
  try {
    final joined = DateTime.parse(referredAt).toLocal();
    final unlock = joined.add(const Duration(days: 3));
    final diff = unlock.difference(DateTime.now());
    if (diff.isNegative) return 0;
    return diff.inDays + 1;
  } catch (_) { return 0; }
}

String _fmtDate(String? s) {
  if (s == null) return '';
  try {
    final d = DateTime.parse(s).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  } catch (_) { return ''; }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});
  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  bool _loading = true;
  bool _refreshing = false;
  bool _transferring = false;
  bool _transferDialogVisible = false;
  bool _qrVisible = false;

  String _code = '';
  Map<String, dynamic>? _stats;
  Map<String, dynamic> _settings = {'bonus_per_referral': 5};
  List<Map<String, dynamic>> _referrals = [];
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!_refreshing) setState(() => _loading = true);
    await Future.wait([_loadCode(), _loadStats(), _loadReferrals(1)]);
    if (mounted) setState(() { _loading = false; _refreshing = false; });
  }

  Future<void> _loadCode() async {
    try {
      final res = await dioClient.get('/v1/referral/my-code');
      if (mounted && res.data['success'] == true) {
        final d = res.data['data'];
        setState(() => _code = d?['referral_code']?.toString() ?? d?['code']?.toString() ?? '');
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final res = await dioClient.get('/v1/referral/stats');
      if (mounted && res.data['success'] == true) {
        final d = res.data['data'];
        setState(() {
          _stats = d?['stats'] != null ? Map<String, dynamic>.from(d!['stats'] as Map) : null;
          if (d?['settings'] != null) _settings = Map<String, dynamic>.from(d!['settings'] as Map);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReferrals(int page) async {
    try {
      final res = await dioClient.get('/v1/referral/my-referrals', queryParameters: {'page': page, 'limit': 20});
      if (mounted && res.data['success'] == true) {
        final d = res.data['data'];
        final list = (d?['referrals'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final totalPages = (d?['totalPages'] as num?)?.toInt() ?? 1;
        setState(() {
          _referrals = page == 1 ? list : [..._referrals, ...list];
          _page = page;
          _hasMore = page < totalPages;
        });
      }
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _loadAll();
  }

  void _copyLink() {
    final link = 'https://play.google.com/store/apps/details?id=com.witalk&referrer=referral_code%3D$_code';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral link copied!', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Color(0xFF10B981)));
  }

  Future<void> _share() async {
    final msg = 'Join WiTalk using my referral code: $_code\n\nGet amazing rewards when you sign up!\n\nDownload now: https://play.google.com/store/apps/details?id=com.witalk&referrer=referral_code%3D$_code';
    await Share.share(msg, subject: 'Join WiTalk!');
  }

  Future<void> _transferToWallet() async {
    final balance = double.tryParse(_stats?['balance']?.toString() ?? '0') ?? 0;
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No referral balance to transfer', style: TextStyle(fontFamily: 'Outfit')), backgroundColor: Color(0xFFEF4444)));
      return;
    }
    setState(() => _transferDialogVisible = true);
  }

  Future<void> _confirmTransfer() async {
    setState(() { _transferDialogVisible = false; _transferring = true; });
    try {
      final res = await dioClient.post('/v1/referral/transfer-to-wallet');
      if (mounted && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message']?.toString() ?? 'Transferred!', style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: const Color(0xFF10B981)));
        await _loadStats();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((e as dynamic)?.response?.data?['message'] ?? 'Transfer failed', style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: const Color(0xFFEF4444)));
    } finally { if (mounted) setState(() => _transferring = false); }
  }

  String get _referralLink => 'https://play.google.com/store/apps/details?id=com.witalk&referrer=referral_code%3D$_code';

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);

    if (_loading) return _skeleton(t);

    final balance = double.tryParse(_stats?['balance']?.toString() ?? '0') ?? 0;
    final bonus = _settings['bonus_per_referral']?.toString() ?? '5';

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(child: Stack(children: [
        Column(children: [
          // Header
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
            child: Row(children: [
              GestureDetector(onTap: () => context.pop(), child: Container(width: 40, height: 56, alignment: Alignment.center, child: Icon(Icons.arrow_back, size: 24, color: t.text))),
              Expanded(child: Text('Invite Friends', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 20, color: t.text))),
              GestureDetector(onTap: _onRefresh, child: Container(width: 40, height: 56, alignment: Alignment.center, child: Icon(Icons.refresh, size: 24, color: t.text))),
            ]),
          ),
          Expanded(child: RefreshIndicator(
            color: t.primary,
            backgroundColor: t.surface,
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                // Code card (gradient)
                _codeCard(t, bonus),
                // How it works
                _howItWorksCard(t, bonus),
                // Stats card
                if (_stats != null) _statsCard(t, balance),
                // Referrals list
                _referralsList(t),
                const SizedBox(height: 24),
              ]),
            ),
          )),
        ]),

        // QR modal
        if (_qrVisible) _qrModal(t),

        // Transfer dialog
        if (_transferDialogVisible) _transferDialog(t, balance),
      ])),
    );
  }

  // ── Code card ────────────────────────────────────────────────────────────────
  Widget _codeCard(_T t, String bonus) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [t.primary, _darken(t.primary)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: [
      const Text('Your Referral Code', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 16, color: Color(0xE6FFFFFF))),
      const SizedBox(height: 12),
      Text(_code, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white, letterSpacing: 2)),
      const SizedBox(height: 8),
      Text('Invite friends — earn ₹$bonus once they use the app for 3 days!', style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xE6FFFFFF)), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _actionBtn(Icons.content_copy, 'Copy', _copyLink),
        const SizedBox(width: 12),
        _actionBtn(Icons.share, 'Share', _share),
        const SizedBox(width: 12),
        _actionBtn(Icons.qr_code, 'QR Code', () => setState(() => _qrVisible = true)),
      ]),
    ]),
  );

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
      ]),
    ),
  );

  // ── How it works ─────────────────────────────────────────────────────────────
  Widget _howItWorksCard(_T t, String bonus) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('How it works', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 16, color: t.text)),
      const SizedBox(height: 16),
      _ruleRow('1', t.primary, t.primary.withValues(alpha: 0.12), 'Share your code with a friend', t),
      _ruleRow('2', t.primary, t.primary.withValues(alpha: 0.12), 'Your friend signs up using your code', t),
      _ruleRow('3', const Color(0xFFFF9F0A), const Color(0x20FF9F0A), 'They use the app for ', t, boldSuffix: '3 days', suffixColor: const Color(0xFFFF9F0A)),
      _ruleRow('4', const Color(0xFF10B981), const Color(0x2010B981), 'You earn ', t, boldSuffix: '₹$bonus', suffixColor: const Color(0xFF10B981), trailText: ' credited to your referral balance'),
    ]),
  );

  Widget _ruleRow(String num, Color numColor, Color numBg, String text, _T t, {String? boldSuffix, Color? suffixColor, String? trailText}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: numBg, shape: BoxShape.circle), child: Center(child: Text(num, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 13, color: numColor)))),
      const SizedBox(width: 12),
      Expanded(child: boldSuffix == null
          ? Text(text, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary))
          : Text.rich(TextSpan(text: text, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary), children: [
              TextSpan(text: boldSuffix, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: suffixColor ?? t.primary)),
              if (trailText != null) TextSpan(text: trailText, style: TextStyle(color: t.textSecondary)),
            ]))),
    ]),
  );

  // ── Stats card ───────────────────────────────────────────────────────────────
  Widget _statsCard(_T t, double balance) {
    final pending = _referrals.where((r) => r['bonus_awarded'] != true).length;
    final hasBalance = balance > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Available Balance', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary)),
            const SizedBox(height: 4),
            Text('₹${balance.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 32, color: t.primary)),
            if (pending > 0) Text('$pending reward${pending > 1 ? 's' : ''} pending', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFFFF9F0A))),
          ]),
          GestureDetector(
            onTap: _transferring ? null : _transferToWallet,
            child: Opacity(opacity: _transferring ? 0.7 : 1, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasBalance ? t.walletBtnBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: hasBalance ? null : Border.all(color: t.textTertiary),
              ),
              child: _transferring
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(children: [
                      Icon(Icons.account_balance_wallet, size: 18, color: hasBalance ? Colors.white : t.textTertiary),
                      const SizedBox(width: 6),
                      Text('Add to WiWallet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: hasBalance ? Colors.white : t.textTertiary)),
                    ]),
            )),
          ),
        ]),
        Container(height: 1, color: t.border, margin: const EdgeInsets.symmetric(vertical: 20)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _statItem('${_stats?['total_referrals'] ?? 0}', 'Total', t.primary, t),
          _statItem('${_stats?['pending_referrals'] ?? 0}', 'Pending', const Color(0xFFFF9F0A), t),
          _statItem('${_stats?['verified_referrals'] ?? 0}', 'Rewarded', const Color(0xFF34C759), t),
          _statItem('₹${(double.tryParse(_stats?['total_bonus_earned']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}', 'Earned', const Color(0xFF10B981), t),
        ]),
        const SizedBox(height: 12),
        Text('* Rewards unlock after your friend uses the app for 3 days', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _statItem(String value, String label, Color color, _T t) => Column(children: [
    Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 22, color: color)),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textSecondary)),
  ]);

  // ── Referrals list ────────────────────────────────────────────────────────────
  Widget _referralsList(_T t) {
    final bonus = _settings['bonus_per_referral']?.toString() ?? '5';
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your Referrals (${_stats?['total_referrals'] ?? 0})', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.text)),
        const SizedBox(height: 16),
        if (_referrals.isEmpty)
          _emptyReferrals(t, bonus)
        else ...[
          ..._referrals.map((r) => _referralItem(r, t)),
          if (_hasMore) GestureDetector(
            onTap: () => _loadReferrals(_page + 1),
            child: Center(child: Padding(padding: const EdgeInsets.only(top: 8), child: Text('Load more', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: t.primary)))),
          ),
        ],
      ]),
    );
  }

  Widget _emptyReferrals(_T t, String bonus) => Column(children: [
    Icon(Icons.person_add, size: 64, color: t.textTertiary),
    const SizedBox(height: 16),
    Text('No referrals yet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18, color: t.textSecondary)),
    const SizedBox(height: 8),
    Text('Share your code — earn ₹$bonus when your friend uses the app for 3 days!', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textTertiary), textAlign: TextAlign.center),
  ]);

  Widget _referralItem(Map<String, dynamic> item, _T t) {
    final name = item['name']?.toString() ?? 'User';
    final username = item['username']?.toString() ?? '';
    final pic = item['profile_pic']?.toString();
    final status = item['status']?.toString();
    final bonusAwarded = item['bonus_awarded'] == true;
    final daysLeft = _daysRemaining(item['referred_at']?.toString());
    final rewardPending = !bonusAwarded && daysLeft > 0;
    final color = _statusColor(status);
    final bonus = _settings['bonus_per_referral']?.toString() ?? '5';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        ClipOval(child: pic != null && pic.isNotEmpty
            ? CachedNetworkImage(imageUrl: pic, width: 50, height: 50, fit: BoxFit.cover)
            : Container(width: 50, height: 50, color: t.primary, alignment: Alignment.center, child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16, color: t.text)),
          Text('@$username', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary)),
          rewardPending
              ? Text('Reward unlocks in $daysLeft day${daysLeft != 1 ? 's' : ''}', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFFFF9F0A)))
              : Text('Joined ${_fmtDate(item['referred_at']?.toString())}', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: t.textTertiary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(_statusLabel(status, bonusAwarded), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: color)),
          ),
          const SizedBox(height: 4),
          Text(bonusAwarded ? '+₹$bonus' : '⏳ pending', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 14, color: bonusAwarded ? const Color(0xFF10B981) : const Color(0xFFFF9F0A))),
        ]),
      ]),
    );
  }

  // ── QR Modal ─────────────────────────────────────────────────────────────────
  Widget _qrModal(_T t) => GestureDetector(
    onTap: () => setState(() => _qrVisible = false),
    child: Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(child: GestureDetector(
        onTap: () {},
        child: Container(
          width: MediaQuery.of(context).size.width - 48,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Scan to Join', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 20, color: t.text)),
            const SizedBox(height: 6),
            Text('Let your friend scan this code to sign up with your referral', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: t.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: QrImageView(data: _referralLink, version: QrVersions.auto, size: 220)),
            const SizedBox(height: 16),
            Text(_code, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 15, color: t.textSecondary, letterSpacing: 2)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => setState(() => _qrVisible = false),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Close', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white))),
              ),
            ),
          ]),
        ),
      )),
    ),
  );

  // ── Transfer dialog ───────────────────────────────────────────────────────────
  Widget _transferDialog(_T t, double balance) => GestureDetector(
    onTap: () => setState(() => _transferDialogVisible = false),
    child: Container(color: Colors.black.withValues(alpha: 0.5), child: Center(child: GestureDetector(onTap: () {}, child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Transfer to WiWallet', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 17, color: t.text)),
        const SizedBox(height: 8),
        Text('Transfer ₹${balance.toStringAsFixed(2)} from your referral earnings to WiWallet?', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: t.textSecondary)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => setState(() => _transferDialogVisible = false), child: Text('Cancel', style: TextStyle(fontFamily: 'Outfit', color: t.textTertiary))),
          const SizedBox(width: 8),
          TextButton(onPressed: _confirmTransfer, child: const Text('Transfer', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: Color(0xFF10B981)))),
        ]),
      ]),
    )))),
  );

  // ── Skeleton ─────────────────────────────────────────────────────────────────
  Widget _skeleton(_T t) => Scaffold(
    backgroundColor: t.bg,
    body: SafeArea(child: Column(children: [
      Container(
        height: 56,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
        child: Row(children: [
          const SizedBox(width: 40),
          Expanded(child: Text('Invite Friends', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 20, color: t.text))),
          const SizedBox(width: 40),
        ]),
      ),
      Expanded(child: Shimmer.fromColors(baseColor: t.skBase, highlightColor: t.skHi, child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(height: 200, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: t.skBase, borderRadius: BorderRadius.circular(16))),
        Container(height: 150, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: t.skBase, borderRadius: BorderRadius.circular(16))),
      ]))),
    ])),
  );

  Color _darken(Color c) => Color.fromARGB(c.alpha, (c.red * 0.7).toInt(), (c.green * 0.7).toInt(), (c.blue * 0.7).toInt());
}
