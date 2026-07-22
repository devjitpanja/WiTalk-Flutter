import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';

class CommunityAddaCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Function(Map<String, dynamic> room) onJoinRoom;

  const CommunityAddaCard({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onJoinRoom,
  });

  @override
  State<CommunityAddaCard> createState() => _CommunityAddaCardState();
}

class _CommunityAddaCardState extends State<CommunityAddaCard> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = widget.item['communityName']?.toString() ?? 'Community';
    final picture = widget.item['communityPicture']?.toString();
    final memberCount = widget.item['memberCount'];
    final isMonetized = widget.item['isMonetized'] == true;
    final passRequired = widget.item['passRequired'] == true;
    final addas = (widget.item['addas'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final gradientColors = isDark
        ? const [Color(0xFF130828), Color(0xFF18093E), Color(0xFF1E1048)]
        : const [Color(0xFFFFFFFF), Color(0xFFF5F3FF), Color(0xFFEDE9FE)];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              InkWell(
                onTap: widget.onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF7C3AED).withOpacity(0.2),
                        backgroundImage: picture != null && picture.isNotEmpty
                            ? CachedNetworkImageProvider(picture)
                            : null,
                        child: picture == null || picture.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: c.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Outfit',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${addas.length} Live',
                                    style: const TextStyle(
                                      color: Color(0xFF7C3AED),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (memberCount != null) ...[
                                  Icon(Icons.people_outline, size: 14, color: c.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$memberCount members',
                                    style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit'),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (isMonetized)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '👑 Premium',
                                      style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                if (passRequired)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '🎟️ Pass Required',
                                      style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        widget.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: const Color(0xFF7C3AED),
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable rooms section
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  children: [
                    const Divider(height: 1, color: Color(0xFF8B5CF6)),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: addas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final room = addas[i];
                        final topic = room['topic']?.toString() ?? room['room_name']?.toString() ?? 'Community Adda';
                        final hostName = room['host_name']?.toString() ?? room['host_username']?.toString() ?? '';
                        final hostPic = room['host_profile_pic']?.toString();
                        final participants = room['current_participants_count'] ?? 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.surface.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: c.border.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'LIVE',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      topic,
                                      style: TextStyle(
                                        color: c.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Outfit',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: c.border,
                                    backgroundImage: hostPic != null && hostPic.isNotEmpty
                                        ? CachedNetworkImageProvider(hostPic)
                                        : null,
                                    child: hostPic == null || hostPic.isEmpty
                                        ? Text(
                                            hostName.isNotEmpty ? hostName[0].toUpperCase() : '?',
                                            style: TextStyle(color: c.text, fontSize: 10),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    hostName,
                                    style: TextStyle(color: c.textSecondary, fontSize: 12, fontFamily: 'Outfit'),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.people, size: 14, color: c.textTertiary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$participants',
                                    style: TextStyle(color: c.textTertiary, fontSize: 12, fontFamily: 'Outfit'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () => widget.onJoinRoom(room),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C3AED),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Join Adda',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                crossFadeState: widget.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
