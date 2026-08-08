import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/theme_provider.dart';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFFFFFFF);
  Color get surface => dark ? const Color(0xFF1a1f2e) : const Color(0xFFFFFFFF);
  Color get border => dark ? const Color(0xFF38383A) : const Color(0xFFE0E0E0);
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary => dark ? const Color(0xFFEBEBF5) : const Color(0xFF666666);
  Color get textTertiary => const Color(0xFF8E8E93);
  Color get chipBg => dark ? const Color(0xFF2a3142) : const Color(0xFFF5F5F5);
  Color get infoBg => dark ? const Color(0xFF1a2332) : const Color(0xFFE3F2FD);
  Color get infoBorder => dark ? const Color(0xFF2a3f5f) : const Color(0xFF90CAF9);
  Color get infoText => dark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0);
  Color get infoIcon => dark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2);
}

class FormerUsernamesScreen extends ConsumerWidget {
  final String username;
  final List<dynamic> usernameHistory;

  const FormerUsernamesScreen({
    super.key,
    required this.username,
    required this.usernameHistory,
  });

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return '';
    }
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      final diffDays = DateTime.now().difference(date).inDays.abs();
      if (diffDays < 7) return '$diffDays days ago';
      if (diffDays < 30) return '${(diffDays / 7).floor()} weeks ago';
      if (diffDays < 365) return '${(diffDays / 30).floor()} months ago';
      return '${(diffDays / 365).floor()} years ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    final usernameChangeCount = usernameHistory.length;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: t.bg,
                border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back, size: 24, color: t.text),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Username History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Summary Card
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: t.border),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF9800),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.history, size: 32, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '@$username',
                            style: TextStyle(
                              fontSize: 22,
                              fontFamily: 'Outfit', fontWeight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'has changed their username',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Outfit',
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$usernameChangeCount ${usernameChangeCount == 1 ? 'time' : 'times'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Info Banner
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.infoBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.infoBorder),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 20, color: t.infoIcon),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Username changes help verify account authenticity and prevent impersonation',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Outfit',
                                color: t.infoText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // History list or empty state
                  if (usernameHistory.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Icon(Icons.update, size: 20, color: t.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Previous Usernames',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                              color: t.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...List.generate(usernameHistory.length, (index) {
                      final item = usernameHistory[index] as Map;
                      final changedAt = item['changed_at'] as String?;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.border),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: t.chipBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                                      color: t.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.alternate_email, size: 16, color: t.textSecondary),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '${item['old_username'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                                              color: t.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: t.textTertiary),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(changedAt),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'Outfit',
                                            color: t.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: t.chipBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getTimeAgo(changedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Outfit', fontWeight: FontWeight.w500,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, size: 64, color: t.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            'No username changes recorded',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Outfit', fontWeight: FontWeight.w600,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This account has maintained the same username',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Outfit',
                              color: t.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
