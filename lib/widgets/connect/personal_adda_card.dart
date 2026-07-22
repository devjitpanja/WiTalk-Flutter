import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/theme_colors.dart';
import 'wave_bar_anim.dart';

class PersonalAddaCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final int paletteIndex;
  final Function(Map<String, dynamic> room) onJoinRoom;

  const PersonalAddaCard({
    super.key,
    required this.room,
    required this.paletteIndex,
    required this.onJoinRoom,
  });

  static const List<Map<String, dynamic>> palettes = [
    {
      'light': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFD1FAE5)],
      'dark': [Color(0xFF0C1F12), Color(0xFF0C1F12), Color(0xFF0A2A17)],
      'border': Color(0xFF22C55E),
      'accent': Color(0xFF16A34A),
      'joinGradient': [Color(0xFF16A34A), Color(0xFF22C55E)],
    },
    {
      'light': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFEDE9FE)],
      'dark': [Color(0xFF170D2A), Color(0xFF170D2A), Color(0xFF1E1038)],
      'border': Color(0xFFA855F7),
      'accent': Color(0xFF7C3AED),
      'joinGradient': [Color(0xFF7C3AED), Color(0xFFA855F7)],
    },
    {
      'light': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFED7AA)],
      'dark': [Color(0xFF1F1208), Color(0xFF1F1208), Color(0xFF291608)],
      'border': Color(0xFFF97316),
      'accent': Color(0xFFEA580C),
      'joinGradient': [Color(0xFFEA580C), Color(0xFFF97316)],
    },
    {
      'light': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFDBEAFE)],
      'dark': [Color(0xFF071523), Color(0xFF071523), Color(0xFF071F30)],
      'border': Color(0xFF3B82F6),
      'accent': Color(0xFF2563EB),
      'joinGradient': [Color(0xFF2563EB), Color(0xFF3B82F6)],
    },
    {
      'light': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFECDD3)],
      'dark': [Color(0xFF1A0509), Color(0xFF1A0509), Color(0xFF240710)],
      'border': Color(0xFFF43F5E),
      'accent': Color(0xFFE11D48),
      'joinGradient': [Color(0xFFE11D48), Color(0xFFF43F5E)],
    },
    {
      'light': [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFCCFBF1)],
      'dark': [Color(0xFF061C18), Color(0xFF061C18), Color(0xFF07241E)],
      'border': Color(0xFF14B8A6),
      'accent': Color(0xFF0D9488),
      'joinGradient': [Color(0xFF0D9488), Color(0xFF14B8A6)],
    },
  ];

  String _getVibeBadge(int count) {
    if (count >= 200) return '🔥 On Fire';
    if (count >= 100) return '⚡ High Energy';
    if (count >= 50) return '✨ Buzzing';
    if (count >= 20) return '🎙️ Active';
    return '🌱 New Room';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = palettes[paletteIndex % palettes.length];

    final topic = room['topic']?.toString() ?? room['room_name']?.toString() ?? 'Live Adda';
    final hostName = room['host_name']?.toString() ?? room['host_username']?.toString() ?? 'Host';
    final hostPic = room['host_profile_pic']?.toString();
    final participantsCount = room['current_participants_count'] as int? ?? 1;
    final isVerified = room['is_host_verified'] == true || room['is_host_verified'] == 1;

    final gradientColors = (isDark ? palette['dark'] : palette['light']) as List<Color>;
    final borderColor = palette['border'] as Color;
    final accentColor = palette['accent'] as Color;
    final joinGradient = palette['joinGradient'] as List<Color>;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top tags row
              Row(
                children: [
                  // LIVE badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 6),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Vibe badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getVibeBadge(participantsCount),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Sound wave animation
                  Row(
                    children: List.generate(
                      4,
                      (idx) => WaveBar(index: idx, color: accentColor, height: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Room Topic
              Text(
                topic,
                style: TextStyle(
                  color: c.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),

              // Host & Participants info
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: c.border,
                    backgroundImage: hostPic != null && hostPic.isNotEmpty
                        ? CachedNetworkImageProvider(hostPic)
                        : null,
                    child: hostPic == null || hostPic.isEmpty
                        ? Text(
                            hostName.isNotEmpty ? hostName[0].toUpperCase() : '?',
                            style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hostName,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, size: 14, color: accentColor),
                          ],
                        ],
                      ),
                      Text(
                        'Host',
                        style: TextStyle(color: c.textTertiary, fontSize: 11, fontFamily: 'Outfit'),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Participants count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surface.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 14, color: c.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '$participantsCount',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Join Adda Action Button
              SizedBox(
                width: double.infinity,
                height: 42,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: joinGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () => onJoinRoom(room),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Join Adda',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
