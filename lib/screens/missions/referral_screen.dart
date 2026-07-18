import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});
  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}
class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final codeRes = await dioClient.get('/v1/referral/my-code');
      final statsRes = await dioClient.get('/v1/referral/stats');
      if (mounted) setState(() => _data = {
        'code': codeRes.data['data']?['code'] ?? codeRes.data['data']?['referralCode'] ?? '',
        'referral_count': statsRes.data['data']?['total_referrals'] ?? statsRes.data['data']?['referral_count'] ?? 0,
        'coins_earned': statsRes.data['data']?['coins_earned'] ?? 0,
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }
  @override
  Widget build(BuildContext context) {
    final code = _data?['code'] ?? '';
    final count = _data?['referral_count'] ?? 0;
    final coins = _data?['coins_earned'] ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Referral', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton)) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5B51F4), Color(0xFF0A84FF)]), borderRadius: BorderRadius.circular(20)), child: Column(children: [
          const Text('🎁', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Invite Friends, Earn Rewards', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Outfit'), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text('Share your code and earn coins for every friend who joins', style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Outfit'), textAlign: TextAlign.center),
        ])),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(children: [
          const Text('Your Referral Code', style: TextStyle(color: AppColors.textTertiary, fontSize: 13, fontFamily: 'Outfit')),
          const SizedBox(height: 8),
          Text(code, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, fontFamily: 'Outfit', letterSpacing: 4)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: () => Share.share('Join WiTalk with my referral code: $code\nhttps://witalk.in/ref/$code'), icon: const Icon(Icons.share, size: 18), label: const Text('Share Code', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryButton, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
        ])),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _stat('$count', 'Friends Joined')),
          const SizedBox(width: 12),
          Expanded(child: _stat('$coins', 'Coins Earned')),
        ]),
      ])),
    );
  }
  Widget _stat(String val, String label) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Column(children: [Text(val, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Outfit')), Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontFamily: 'Outfit'))]));
}