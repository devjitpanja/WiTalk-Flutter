import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../theme/theme_colors.dart';
import '../../providers/auth_provider.dart';

class AddaShareCard extends StatefulWidget {
  final Map<String, dynamic>? room;
  final DateTime? sessionStartedAt;
  final bool isHost;

  const AddaShareCard({
    super.key,
    this.room,
    this.sessionStartedAt,
    this.isHost = false,
  });

  @override
  State<AddaShareCard> createState() => _AddaShareCardState();
}

class _AddaShareCardState extends State<AddaShareCard> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Map<String, String> _getDynamicContent({
    required int streakDays,
    required int minutesTalked,
    required int totalConversations,
    required int totalParticipants,
    String? language,
    String? topic,
  }) {
    final isEnglish = language?.toLowerCase().contains('english') == true;
    final isFriendship = topic?.toLowerCase().contains('friend') == true;
    final isBigRoom = totalParticipants >= 10;

    if (totalConversations <= 1 && streakDays <= 1) {
      return {'headline': 'First conversation done.', 'sub': 'The hardest one is always the first.', 'badge': '🌱 Just started'};
    }
    if (minutesTalked >= 30) {
      return {'headline': '$minutesTalked minutes of real talk.', 'sub': "That's not studying. That's using English.", 'badge': '🔥 Long session'};
    }
    if (streakDays >= 30) {
      return {'headline': '$streakDays-day streak.', 'sub': "A month of showing up. That's rare.", 'badge': '🏆 Monthly streak'};
    }
    if (streakDays >= 7) {
      return {'headline': '$streakDays days straight.', 'sub': 'Consistency is the real skill.', 'badge': '🔥 Weekly streak'};
    }
    if (isBigRoom) {
      return {'headline': 'Spoke with $totalParticipants people.', 'sub': 'One room. Many voices. Real English.', 'badge': '🎙️ Big room'};
    }
    if (streakDays >= 3) {
      return {'headline': '$streakDays-day streak.', 'sub': 'Building a habit that actually sticks.', 'badge': '🗓️ $streakDays days'};
    }
    if (isFriendship) {
      return {'headline': 'Made connections today.', 'sub': 'Language is just the bridge.', 'badge': '🤝 Friendship room'};
    }
    if (isEnglish) {
      return {'headline': 'English practice done.', 'sub': 'Real conversation > grammar drills.', 'badge': '🇬🇧 English room'};
    }
    return {'headline': 'Showed up today.', 'sub': 'Daily practice builds real fluency.', 'badge': '🎙️ Adda session'};
  }

  Map<String, String> _getHostDynamicContent({
    required int minutesTalked,
    required int totalListeners,
    required int totalParticipants,
    String? topic,
  }) {
    final listeners = totalListeners > 0 ? totalListeners : totalParticipants;

    if (listeners >= 20) {
      return {'headline': '$listeners listeners tuned in.', 'sub': 'You built a room people wanted to be in.', 'badge': '🏆 Packed house'};
    }
    if (listeners >= 10) {
      return {'headline': '$listeners people joined your Adda.', 'sub': 'Your room had real pull today.', 'badge': '🔥 Big session'};
    }
    if (minutesTalked >= 45) {
      return {'headline': '$minutesTalked-minute Adda hosted.', 'sub': 'Deep conversations take time. Worth it.', 'badge': '⏱️ Long session'};
    }
    if (listeners >= 5) {
      return {'headline': 'You hosted $listeners listeners.', 'sub': 'Every great community starts right here.', 'badge': '🎙️ Host session'};
    }
    if (topic != null && topic.isNotEmpty) {
      return {'headline': '"$topic" wrapped.', 'sub': 'You gave people a space to talk.', 'badge': '🎙️ Host'};
    }
    return {'headline': 'Adda hosted. Done.', 'sub': 'You showed up and led the room.', 'badge': '🎙️ Host'};
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Future<void> _handleShareOther() async {
    // Sharing logic using share_plus and screenshot
    setState(() => _sharing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room ?? {};
    final userName = room['host_name']?.toString() ?? 'User';
    final userAvatar = room['host_profile_pic']?.toString();
    final username = room['host_username']?.toString() ?? 'user';
    final isHost = widget.isHost;

    final minutesTalked = widget.sessionStartedAt != null
        ? max(1, DateTime.now().difference(widget.sessionStartedAt!).inMinutes)
        : 1;

    final streakDays = 1; // mock
    final totalConversations = 1; // mock
    final totalParticipants = room['current_participants_count'] as int? ?? 1;
    final totalListeners = max(0, totalParticipants - 1);
    final roomTopic = room['topic']?.toString();
    final roomLanguage = room['language']?.toString();
    final roomCommunityPicture = room['group_picture']?.toString();

    final dynamicContent = isHost
        ? _getHostDynamicContent(minutesTalked: minutesTalked, totalListeners: totalListeners, totalParticipants: totalParticipants, topic: roomTopic)
        : _getDynamicContent(streakDays: streakDays, minutesTalked: minutesTalked, totalConversations: totalConversations, totalParticipants: totalParticipants, language: roomLanguage, topic: roomTopic);

    final headline = dynamicContent['headline']!;
    final sub = dynamicContent['sub']!;
    final badge = dynamicContent['badge']!;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0B18),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12).copyWith(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      isHost ? 'Your Adda Report' : 'Your Adda Session',
                      style: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  width: 360,
                  height: 450,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F0629), Color(0xFF1E0B52), Color(0xFF2D1072)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: const Color(0xFFAFA9EC).withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF7B61FF).withOpacity(0.4), offset: const Offset(0, 8), blurRadius: 20),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Glow Top Right
                        Positioned(
                          top: -40,
                          right: -40,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF7B61FF).withOpacity(0.18),
                            ),
                          ),
                        ),
                        // Glow Bottom Left
                        Positioned(
                          bottom: -50,
                          left: -30,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFAFA9EC).withOpacity(0.12),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Top Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('WiTalk', style: TextStyle(color: Color(0xFFAFA9EC), fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isHost ? const Color(0xFFFFC400).withOpacity(0.18) : const Color(0xFFAFA9EC).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isHost ? const Color(0xFFFFC400).withOpacity(0.4) : const Color(0xFFAFA9EC).withOpacity(0.35)),
                                    ),
                                    child: Text(badge, style: TextStyle(color: isHost ? const Color(0xFFFFD700) : const Color(0xFFAFA9EC), fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                              if (isHost)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text('👑', style: TextStyle(fontSize: 13)),
                                      SizedBox(width: 5),
                                      Text('HOST', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold, letterSpacing: 2)),
                                    ],
                                  ),
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Avatar
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF7B61FF), width: 2.5),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF7B61FF).withOpacity(0.8), blurRadius: 10),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(34),
                                    child: userAvatar != null && userAvatar.isNotEmpty
                                        ? CachedNetworkImage(imageUrl: userAvatar, fit: BoxFit.cover)
                                        : Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFFAFA9EC)]),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(_getInitials(userName), style: const TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                                          ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 10),
                              Text(userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                              const SizedBox(height: 14),
                              Text(headline, style: const TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'Outfit', fontWeight: FontWeight.bold, height: 1.2), textAlign: TextAlign.center),
                              const SizedBox(height: 6),
                              Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, fontFamily: 'Outfit'), textAlign: TextAlign.center),
                              
                              // Stats Row
                              Container(
                                margin: const EdgeInsets.only(top: 20),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text('$minutesTalked', style: const TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text('MINS', style: TextStyle(color: const Color(0xFFAFA9EC).withOpacity(0.7), fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                                        ],
                                      ),
                                    ),
                                    Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15)),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text(isHost ? '$totalListeners' : '$streakDays', style: TextStyle(color: isHost ? const Color(0xFFFFD700) : Colors.white, fontSize: 26, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(isHost ? 'LISTENERS' : 'STREAK', style: TextStyle(color: const Color(0xFFAFA9EC).withOpacity(0.7), fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                                        ],
                                      ),
                                    ),
                                    Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15)),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Text('$totalParticipants', style: const TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(isHost ? 'TOTAL JOINED' : 'IN ROOM', style: TextStyle(color: const Color(0xFFAFA9EC).withOpacity(0.7), fontSize: 9, fontFamily: 'Outfit', fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // Footer
                              Container(
                                padding: const EdgeInsets.only(top: 12),
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(isHost ? 'Hosted on' : 'Talk with me', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontFamily: 'Outfit')),
                                    Text('witalk.in/$username', style: const TextStyle(color: Color(0xFFAFA9EC), fontSize: 12, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Action Buttons
              SizedBox(
                width: 360,
                child: OutlinedButton(
                  onPressed: _sharing ? null : _handleShareOther,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: const Color(0xFFAFA9EC).withOpacity(0.3)),
                    backgroundColor: const Color(0xFFAFA9EC).withOpacity(0.07),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _sharing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFAFA9EC), strokeWidth: 2))
                      : const Text('Share to other apps', style: TextStyle(color: Color(0xFFAFA9EC), fontSize: 15, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('Not now', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13, fontFamily: 'Outfit')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
