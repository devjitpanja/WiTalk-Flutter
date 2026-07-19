import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/theme_provider.dart';

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF0D1017) : const Color(0xFFF2F2F7);
  Color get surface => dark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get text => dark ? Colors.white : Colors.black;
  Color get textSecondary =>
      dark ? const Color(0xFFEBEBF5) : const Color(0xFF3C3C43);
  Color get accent => const Color(0xFF0751DF);
  Color get infoBannerBg => dark
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFF0751DF).withValues(alpha: 0.071);
  Color get infoBannerBorder => dark
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0xFF0751DF).withValues(alpha: 0.188);
  Color get ruleCardBg => dark
      ? Colors.white.withValues(alpha: 0.04)
      : Colors.white;
  Color get ruleIconBg => dark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF0751DF).withValues(alpha: 0.094);
}

const _kRules = [
  (
    icon: Icons.assignment_turned_in,
    title: 'Complete Missions Properly',
    desc:
        'Finish each mission fully and honestly. Incomplete or rushed submissions may not count toward your points.',
  ),
  (
    icon: Icons.block,
    title: 'No Spamming',
    desc:
        'Do not repeatedly submit the same content or exploit loopholes. Each mission should be completed once with genuine effort.',
  ),
  (
    icon: Icons.group,
    title: 'Contribute Meaningfully',
    desc:
        'Engage with the community in a real and positive way. Meaningful contributions are valued over volume.',
  ),
  (
    icon: Icons.person,
    title: 'One Account Per Person',
    desc:
        'Using multiple accounts to boost your ranking is strictly prohibited and will result in disqualification.',
  ),
  (
    icon: Icons.event_repeat,
    title: 'Monthly Reset',
    desc:
        'Rankings reset at the start of every month. Everyone gets a fresh start — stay consistent to keep your spot.',
  ),
  (
    icon: Icons.gavel,
    title: 'Follow Community Guidelines',
    desc:
        'All platform rules apply here. Violations of community standards will impact your ranking eligibility.',
  ),
];

class RankingRulesScreen extends ConsumerWidget {
  const RankingRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final t = _T(isDark);
    final size = MediaQuery.of(context).size;
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        Container(
          color: t.accent,
          padding: EdgeInsets.fromLTRB(16, top, 16, 16),
          child: Row(children: [
            SizedBox(
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
            Expanded(
              child: Text(
                'Ranking Rules',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: size.width * 0.052,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 40),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 20, 18, bottom + 24 > 32 ? bottom + 24 : 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.infoBannerBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.infoBannerBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.calendar_month, size: 16, color: t.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly Leaderboard',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: size.width * 0.038,
                        color: t.accent,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: size.width * 0.034,
                        color: t.textSecondary,
                        height: 1.45,
                      ),
                      children: [
                        const TextSpan(
                            text:
                                'This leaderboard tracks mission points earned within the current month. Rankings are recalculated and refreshed every day at '),
                        TextSpan(
                          text: '12:00 AM',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: t.text),
                        ),
                        const TextSpan(
                            text:
                                ' — come back after 24 hours to see your updated position. At the end of each month, all scores reset and everyone starts fresh.'),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              Text(
                'COMMUNITY RULES',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: size.width * 0.033,
                  color: t.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              for (final rule in _kRules) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.ruleCardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.ruleIconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(rule.icon, size: 20, color: t.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rule.title,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                fontSize: size.width * 0.038,
                                color: t.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              rule.desc,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: size.width * 0.033,
                                color: t.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.verified, size: 14, color: t.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fair play keeps the community strong. Thank you for being a great member!',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: size.width * 0.032,
                      color: t.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
