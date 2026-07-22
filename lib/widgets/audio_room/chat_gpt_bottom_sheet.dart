import 'package:flutter/material.dart';

class ChatGPTBottomSheet extends StatefulWidget {
  final String? roomContext;

  const ChatGPTBottomSheet({
    super.key,
    this.roomContext,
  });

  @override
  State<ChatGPTBottomSheet> createState() => _ChatGPTBottomSheetState();
}

class _ChatGPTBottomSheetState extends State<ChatGPTBottomSheet> {
  final List<Map<String, dynamic>> _conversationStarters = [
    {
      'emoji': '📰',
      'title': 'Latest News',
      'prompt': null,
      'isDynamic': true,
    },
    {
      'emoji': '🔮',
      'title': 'Would You Rather',
      'prompt': 'I\'m in a WiTalk audio room and we want to play "Would You Rather". Give me interesting, creative, and thought-provoking "Would You Rather" questions that can spark fun debates and discussions. Mix deep, funny, and controversial choices.',
    },
    {
      'emoji': '🎮',
      'title': 'Gaming & Tech Talk',
      'prompt': 'I\'m in a WiTalk audio room discussing gaming and technology. Suggest trending topics, latest tech news, gaming debates, favorite games discussion, tech predictions, and interesting questions about gaming culture and technology.',
    },
    {
      'emoji': '🎬',
      'title': 'Movies & Shows',
      'prompt': 'I\'m in a WiTalk audio room talking about movies and TV shows. Suggest popular series discussions, movie recommendations, plot theories, character debates, and fun questions about entertainment and pop culture.',
    },
    {
      'emoji': '💬',
      'title': 'Hot Takes & Opinions',
      'prompt': 'I\'m in a WiTalk audio room sharing hot takes and controversial opinions. Give me spicy but respectful discussion topics, unpopular opinions, and debate-worthy questions that will get everyone talking.',
    },
    {
      'emoji': '🧠',
      'title': 'Deep Questions',
      'prompt': 'I\'m in a WiTalk audio room having a deep conversation. Give me thought-provoking questions about life, philosophy, psychology, human nature, existence, and meaningful topics that spark profound discussions.',
    },
    {
      'emoji': '😂',
      'title': 'Fun & Games',
      'prompt': 'I\'m in a WiTalk audio room looking for fun activities. Suggest interactive games like "Two Truths and a Lie", storytelling games, improv challenges, funny icebreakers, riddles, and entertaining group activities.',
    },
    {
      'emoji': '🌍',
      'title': 'Travel & Culture',
      'prompt:': 'I\'m in a WiTalk audio room discussing travel and different cultures. Suggest conversation topics about travel experiences, cultural differences, dream destinations, food from around the world, and interesting cultural facts.',
    },
    {
      'emoji': '🎯',
      'title': 'Practice English',
      'prompt': 'I\'m practicing English in a WiTalk audio room. Help me with engaging conversation topics, useful phrases, vocabulary building exercises, pronunciation tips, and discussion questions that help improve English speaking skills.',
    },
    {
      'emoji': '🌟',
      'title': 'Other',
      'prompt': null,
    },
  ];

  void _handleStarterPress(Map<String, dynamic> starter) {
    // In a real implementation with webview_flutter, this would navigate the webview to ChatGPT URL
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1017),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: const Color(0xFF0751DF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF0751DF).withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10A37F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.psychology, size: 18, color: Color(0xFF10A37F)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ChatGPT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC8D2FF).withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.minimize, size: 20, color: const Color(0xFFC8D2FF).withOpacity(0.8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: const Color(0xFFC8D2FF).withOpacity(0.8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                children: [
                  Text(
                    'Start a Conversation',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFC8D2FF).withOpacity(0.95),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a conversation style or start fresh',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFFC8D2FF).withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  
                  // Grid
                  Column(
                    children: _conversationStarters.map((starter) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _handleStarterPress(starter),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0751DF).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF0751DF).withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Text(starter['emoji'], style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      starter['title'],
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFC8D2FF).withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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

Future<void> showChatGPTBottomSheet({
  required BuildContext context,
  String? roomContext,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ChatGPTBottomSheet(
      roomContext: roomContext,
    ),
  );
}
