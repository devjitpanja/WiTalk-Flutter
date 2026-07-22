import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_colors.dart';

class AddaReviewsScreen extends StatefulWidget {
  final Map<String, dynamic>? room;

  const AddaReviewsScreen({super.key, this.room});

  @override
  State<AddaReviewsScreen> createState() => _AddaReviewsScreenState();
}

class _AddaReviewsScreenState extends State<AddaReviewsScreen> {
  bool _loading = false;
  
  // Mock Data
  final Map<String, dynamic> _ratingStats = {
    'average': '4.8',
    'total': 124,
    'distribution': { '5': 95, '4': 20, '3': 5, '2': 2, '1': 2 },
    'topTags': [
      {'tag': 'Great conversation', 'count': 45},
      {'tag': 'Friendly users', 'count': 32},
      {'tag': 'Helpful discussion', 'count': 21},
    ]
  };

  final List<Map<String, dynamic>> _reviews = [
    {
      'id': '1',
      'user_name': 'Sarah',
      'created_at': '2023-10-15T10:00:00Z',
      'rating': '5.0',
      'review_text': 'Such an amazing room! I really enjoyed the conversation and the host was very welcoming.',
      'feedback_tags': ['Great conversation', 'Friendly users'],
      'helpful_count': 12,
      'my_vote': null,
    },
    {
      'id': '2',
      'user_name': 'Alex',
      'created_at': '2023-10-12T14:30:00Z',
      'rating': '4.0',
      'review_text': 'Good talk, but there were some background noises. Still learned a lot.',
      'feedback_tags': ['Helpful discussion'],
      'helpful_count': 3,
      'my_vote': 'helpful',
    }
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background = isDark ? const Color(0xFF080B10) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0D1017).withOpacity(0.7) : Colors.white;
    final borderCol = isDark ? const Color(0xFF0751DF).withOpacity(0.15) : const Color(0xFFE2E8F0);
    final textMain = isDark ? const Color(0xFFEBEBF5) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFFEBEBF5).withOpacity(0.6) : const Color(0xFF64748B);
    const accent = Color(0xFF0751DF);
    final dividerCol = isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: textMain),
          onPressed: () => context.pop(),
        ),
        title: Text('Adda Reviews', style: TextStyle(color: textMain, fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8).copyWith(bottom: 100),
              children: [
                _buildRatingOverview(cardBg, borderCol, textMain, textMuted, dividerCol, isDark),
                const SizedBox(height: 16),
                ..._reviews.map((r) => _buildReviewCard(r, cardBg, borderCol, textMain, textMuted, accent, dividerCol, isDark)),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.star_outline, size: 18, color: Colors.white),
          label: const Text('Write a Review', style: TextStyle(fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingOverview(Color cardBg, Color borderCol, Color textMain, Color textMuted, Color dividerCol, bool isDark) {
    final avg = double.tryParse(_ratingStats['average']) ?? 0.0;
    final total = _ratingStats['total'] as int;
    final dist = _ratingStats['distribution'] as Map<String, dynamic>;
    final tags = _ratingStats['topTags'] as List;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: borderCol),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Big Rating
              Container(
                width: 120,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0751DF).withOpacity(0.18), const Color(0xFF0751DF).withOpacity(0.06)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(_ratingStats['average'], style: const TextStyle(color: Colors.orange, fontSize: 36, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) => Icon(
                        index < avg.floor() ? Icons.star : (index == avg.floor() && avg % 1 >= 0.5 ? Icons.star_half : Icons.star_border),
                        color: Colors.orange,
                        size: 14,
                      )),
                    ),
                    const SizedBox(height: 4),
                    Text('$total reviews', style: TextStyle(color: textMuted, fontSize: 11, fontFamily: 'Outfit')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right: Bars
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((star) {
                    final count = dist[star.toString()] as int? ?? 0;
                    final pct = total > 0 ? count / total : 0.0;
                    final barColor = star >= 4 ? const Color(0xFF22C55E) : star == 3 ? Colors.orange : const Color(0xFFEF4444);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text('$star', style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Outfit')),
                          const SizedBox(width: 2),
                          const Icon(Icons.star, color: Colors.orange, size: 10),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2433) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.4 * pct,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(width: 24, child: Text('$count', style: TextStyle(color: textMuted, fontSize: 11, fontFamily: 'Outfit'))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            Container(margin: const EdgeInsets.symmetric(vertical: 16), height: 1, color: dividerCol),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('What people are saying', style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Outfit')),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((t) {
                final tagStr = t['tag'] as String;
                final bool isPos = tagStr.contains('Great') || tagStr.contains('Friendly') || tagStr.contains('Helpful');
                final bg = isPos ? (isDark ? const Color(0xFF22C55E).withOpacity(0.12) : const Color(0xFFF0FDF4)) : (isDark ? const Color(0xFFEAB308).withOpacity(0.12) : const Color(0xFFFEFCE8));
                final border = isPos ? (isDark ? const Color(0xFF4ADE80).withOpacity(0.25) : const Color(0xFFBBF7D0)) : (isDark ? const Color(0xFFFACC15).withOpacity(0.25) : const Color(0xFFFDE68A));
                final textC = isPos ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)) : (isDark ? const Color(0xFFFACC15) : const Color(0xFFCA8A04));

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tagStr, style: TextStyle(color: textC, fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(4)),
                        child: Text('${t['count']}', style: TextStyle(color: textC, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> item, Color cardBg, Color borderCol, Color textMain, Color textMuted, Color accent, Color dividerCol, bool isDark) {
    final tags = (item['feedback_tags'] as List?)?.cast<String>() ?? [];
    final helpfulCount = item['helpful_count'] as int? ?? 0;
    final myVote = item['my_vote'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, border: Border.all(color: borderCol), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['user_name']}***', style: TextStyle(color: textMain, fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    Text('Oct 15, 2023', style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Outfit')),
                  ],
                ),
              ),
              Icon(Icons.more_vert, color: textMuted, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) => Icon(
              i < double.parse(item['rating']).floor() ? Icons.star : Icons.star_border,
              color: Colors.orange,
              size: 16,
            )),
          ),
          const SizedBox(height: 12),
          Text(item['review_text'], style: TextStyle(color: textMain, fontSize: 14, fontFamily: 'Outfit', height: 1.5)),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: isDark ? accent.withOpacity(0.15) : const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                child: Text(t, style: TextStyle(color: accent, fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
              )).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: dividerCol))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (helpfulCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('$helpfulCount people found this helpful', style: TextStyle(color: textMuted, fontSize: 12, fontFamily: 'Outfit')),
                  ),
                Row(
                  children: [
                    Text('Did you find this helpful?', style: TextStyle(color: textMuted, fontSize: 13, fontFamily: 'Outfit')),
                    const SizedBox(width: 8),
                    _buildVoteBtn('Yes', Icons.thumb_up, myVote == 'helpful', accent, textMuted, isDark),
                    const SizedBox(width: 8),
                    _buildVoteBtn('No', Icons.thumb_down, myVote == 'not_helpful', Colors.red, textMuted, isDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteBtn(String label, IconData icon, bool selected, Color selectedCol, Color textMuted, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? selectedCol.withOpacity(0.15) : Colors.transparent,
        border: Border.all(color: selected ? selectedCol : (isDark ? const Color(0xFF2D3748) : const Color(0xFFCBD5E1))),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: selected ? selectedCol : textMuted),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: selected ? selectedCol : textMuted, fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
