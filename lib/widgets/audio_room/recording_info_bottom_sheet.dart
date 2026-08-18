import 'package:flutter/material.dart';

const _kPolicyPoints = [
  _PolicyPoint(
    icon: Icons.mic,
    color: Color(0xFFEF4444),
    title: 'Session Recorded',
    desc:
        'This Adda session is being recorded for quality assurance and safety review purposes.',
  ),
  _PolicyPoint(
    icon: Icons.warning_rounded,
    color: Color(0xFFF59E0B),
    title: 'Hate Speech & Harassment',
    desc:
        'Spreading hate, bullying, or making threats against others is strictly prohibited.',
  ),
  _PolicyPoint(
    icon: Icons.gavel_rounded,
    color: Color(0xFF8B5CF6),
    title: 'Misinformation',
    desc:
        'Deliberately sharing false or misleading information that could harm others is not allowed.',
  ),
  _PolicyPoint(
    icon: Icons.verified_user_rounded,
    color: Color(0xFF10B981),
    title: 'Your Safety is Priority',
    desc:
        'Recordings are reviewed only when a report is filed. Your privacy is protected.',
  ),
  _PolicyPoint(
    icon: Icons.history_rounded,
    color: Color(0xFF3B82F6),
    title: 'Accountability',
    desc:
        'Participants found violating community guidelines may face bans or further action.',
  ),
];

class _PolicyPoint {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _PolicyPoint(
      {required this.icon,
      required this.color,
      required this.title,
      required this.desc});
}

class RecordingInfoBottomSheet extends StatefulWidget {
  const RecordingInfoBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RecordingInfoBottomSheet(),
    );
  }

  @override
  State<RecordingInfoBottomSheet> createState() =>
      _RecordingInfoBottomSheetState();
}

class _RecordingInfoBottomSheetState extends State<RecordingInfoBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotCtrl;
  late final Animation<double> _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 1.0, end: 0.15).animate(_dotCtrl);
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF10161E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0x40EF4444), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x66EF4444),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // REC badge row
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _dotAnim,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'REC',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Title
                  const Center(
                    child: Text(
                      'This Adda is Being Recorded',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Subtitle
                  const Center(
                    child: Text(
                      'To keep WiTalk safe for everyone, this session is being recorded.',
                      style: TextStyle(
                        color: Color(0x8CFFFFFF),
                        fontSize: 14,
                        fontFamily: 'Outfit',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Divider
                  Container(
                      height: 1,
                      color: const Color(0x12FFFFFF)),
                  const SizedBox(height: 14),
                  // Warm card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x14F472B6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x33F472B6)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.favorite_rounded,
                            color: Color(0xFFF472B6), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Great conversations happen when we listen with respect and speak with kindness.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontFamily: 'Outfit',
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Section label
                  const Text(
                    'COMMUNITY GUIDELINES',
                    style: TextStyle(
                      color: Color(0x59FFFFFF),
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Policy cards
                  ..._kPolicyPoints.map((p) => _PolicyCard(point: p)),
                  const SizedBox(height: 14),
                  // CTA card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x1210B981),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x3310B981)),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          color: Color(0xBFFFFFFF),
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(
                              text:
                                  'Think before you speak. Recordings exist to protect '),
                          TextSpan(
                            text: 'you',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                              text:
                                  ' and every participant in this room.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        shadowColor:
                            const Color(0xFFEF4444).withValues(alpha: 0.35),
                        elevation: 6,
                      ),
                      child: const Text(
                        "Got it, I'll be respectful",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final _PolicyPoint point;
  const _PolicyCard({required this.point});

  @override
  Widget build(BuildContext context) {
    final iconBg = point.color.withValues(alpha: 0.1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x0CFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(point.icon, color: point.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    point.desc,
                    style: const TextStyle(
                      color: Color(0x80FFFFFF),
                      fontSize: 12,
                      fontFamily: 'Outfit',
                      height: 1.4,
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
