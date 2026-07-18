import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class RandomChatScreen extends StatefulWidget {
  const RandomChatScreen({super.key});
  @override
  State<RandomChatScreen> createState() => _RandomChatScreenState();
}

class _RandomChatScreenState extends State<RandomChatScreen> with SingleTickerProviderStateMixin {
  bool _searching = false;
  Timer? _pollTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _startSearch();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSearch() async {
    setState(() => _searching = true);
    try {
      await dioClient.post('/v1/random-chat/join');
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkMatch());
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _checkMatch() async {
    try {
      final res = await dioClient.get('/v1/random-chat/status');
      final data = res.data['data'];
      if (data?['status'] == 'matched') {
        _pollTimer?.cancel();
        final chatId = data['chatId'] as String?;
        if (chatId != null && mounted) {
          context.pushReplacement('/chat/conversation/$chatId');
        }
      }
    } catch (_) {}
  }

  Future<void> _cancel() async {
    _pollTimer?.cancel();
    try { await dioClient.post('/v1/random-chat/leave'); } catch (_) {}
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Random Chat', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _cancel),
    ),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ScaleTransition(
        scale: _pulse,
        child: Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(colors: [AppColors.primaryButton, AppColors.primary, AppColors.primaryButton]),
          ),
          child: const Center(child: Icon(Icons.people_outline, color: Colors.white, size: 64)),
        ),
      ),
      const SizedBox(height: 32),
      const Text('Finding a match...', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
      const SizedBox(height: 8),
      const Text('Connect with someone new right now', style: TextStyle(color: AppColors.textTertiary, fontSize: 15, fontFamily: 'Outfit')),
      const SizedBox(height: 48),
      OutlinedButton(
        onPressed: _cancel,
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), minimumSize: const Size(160, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
        child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    ])),
  );
}
