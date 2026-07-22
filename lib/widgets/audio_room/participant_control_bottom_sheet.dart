import 'package:flutter/material.dart';

class ParticipantControlBottomSheet extends StatelessWidget {
  final Map<String, dynamic>? participant;
  final bool isHost;
  final bool isAdmin;
  final bool isParticipantInSeat;
  final bool isFrozen;
  final VoidCallback onMuteToggle;
  final VoidCallback onKick;
  final VoidCallback onBan;
  final VoidCallback onOffStage;
  final VoidCallback onInviteToSeat;
  final VoidCallback onTurnMicOn;
  final VoidCallback onPromoteToAdmin;
  final VoidCallback onDemoteAdmin;

  const ParticipantControlBottomSheet({
    super.key,
    required this.participant,
    this.isHost = false,
    this.isAdmin = false,
    this.isParticipantInSeat = false,
    this.isFrozen = false,
    required this.onMuteToggle,
    required this.onKick,
    required this.onBan,
    required this.onOffStage,
    required this.onInviteToSeat,
    required this.onTurnMicOn,
    required this.onPromoteToAdmin,
    required this.onDemoteAdmin,
  });

  @override
  Widget build(BuildContext context) {
    if (participant == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 12,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 15),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant?['userName'] ?? 'Participant',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage participant',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          if (isFrozen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 14, color: Color(0xFFA78BFA)),
                  SizedBox(width: 6),
                  Text(
                    'Actions frozen by Platform Moderator',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
                ],
              ),
            ),

          // Options Container
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isParticipantInSeat) ...[
                    if (participant?['isMicOn'] == true)
                      _buildOptionButton(
                        icon: Icons.mic_off,
                        title: 'Mute',
                        description: 'Turn off their microphone',
                        iconColor: const Color(0xFFFFA500),
                        bgColor: const Color(0xFFFFA500).withOpacity(0.15),
                        onTap: onMuteToggle,
                        isFrozen: isFrozen,
                      ),
                    if (participant?['isMicOn'] != true)
                      _buildOptionButton(
                        icon: Icons.mic,
                        title: 'Request Mic On',
                        description: 'Ask them to turn on microphone',
                        iconColor: const Color(0xFF4CAF50),
                        bgColor: const Color(0xFF4CAF50).withOpacity(0.15),
                        onTap: onTurnMicOn,
                        isFrozen: isFrozen,
                      ),
                    _buildOptionButton(
                      icon: Icons.person_remove,
                      title: 'Move Off Stage',
                      description: 'Remove from speaker seats',
                      iconColor: const Color(0xFF4A90E2),
                      bgColor: const Color(0xFF4A90E2).withOpacity(0.15),
                      onTap: onOffStage,
                      isFrozen: isFrozen,
                    ),
                  ] else ...[
                    _buildOptionButton(
                      icon: Icons.event_seat,
                      title: 'Invite to Stage',
                      description: 'Invite them to take a speaker seat',
                      iconColor: const Color(0xFF4CAF50),
                      bgColor: const Color(0xFF4CAF50).withOpacity(0.15),
                      onTap: onInviteToSeat,
                    ),
                  ],

                  if (isHost && participant?['isHost'] != true)
                    _buildOptionButton(
                      icon: participant?['isAdmin'] == true ? Icons.remove_moderator : Icons.add_moderator,
                      title: participant?['isAdmin'] == true ? 'Remove Admin' : 'Make Admin',
                      description: participant?['isAdmin'] == true ? 'Remove admin privileges' : 'Grant admin privileges',
                      iconColor: participant?['isAdmin'] == true ? const Color(0xFFFFA500) : const Color(0xFF4A90E2),
                      bgColor: participant?['isAdmin'] == true ? const Color(0xFFFFA500).withOpacity(0.15) : const Color(0xFF4A90E2).withOpacity(0.15),
                      onTap: participant?['isAdmin'] == true ? onDemoteAdmin : onPromoteToAdmin,
                    ),

                  _buildOptionButton(
                    icon: Icons.exit_to_app,
                    title: 'Kick from Adda',
                    description: 'Remove from the adda (can rejoin)',
                    iconColor: const Color(0xFFFF6B6B),
                    bgColor: const Color(0xFFFF6B6B).withOpacity(0.15),
                    titleColor: const Color(0xFFFF6B6B),
                    onTap: onKick,
                    isFrozen: isFrozen,
                  ),

                  if (isHost || isAdmin)
                    _buildOptionButton(
                      icon: Icons.block,
                      title: 'Ban from Adda',
                      description: 'Remove and block from rejoining',
                      iconColor: const Color(0xFFCC0000),
                      bgColor: const Color(0xFFCC0000).withOpacity(0.12),
                      titleColor: const Color(0xFFCC0000),
                      onTap: onBan,
                      isFrozen: isFrozen,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
    required Color bgColor,
    Color? titleColor,
    required VoidCallback onTap,
    bool isFrozen = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isFrozen ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Opacity(
              opacity: isFrozen ? 0.55 : 1.0,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isFrozen ? iconColor.withOpacity(0.35) : iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: titleColor != null
                                ? (isFrozen ? titleColor.withOpacity(0.4) : titleColor)
                                : (isFrozen ? Colors.white.withOpacity(0.4) : Colors.white),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isFrozen)
                    Icon(
                      Icons.lock,
                      size: 14,
                      color: const Color(0xFFA78BFA).withOpacity(0.6),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showParticipantControlBottomSheet({
  required BuildContext context,
  required Map<String, dynamic>? participant,
  bool isHost = false,
  bool isAdmin = false,
  bool isParticipantInSeat = false,
  bool isFrozen = false,
  required VoidCallback onMuteToggle,
  required VoidCallback onKick,
  required VoidCallback onBan,
  required VoidCallback onOffStage,
  required VoidCallback onInviteToSeat,
  required VoidCallback onTurnMicOn,
  required VoidCallback onPromoteToAdmin,
  required VoidCallback onDemoteAdmin,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ParticipantControlBottomSheet(
      participant: participant,
      isHost: isHost,
      isAdmin: isAdmin,
      isParticipantInSeat: isParticipantInSeat,
      isFrozen: isFrozen,
      onMuteToggle: onMuteToggle,
      onKick: onKick,
      onBan: onBan,
      onOffStage: onOffStage,
      onInviteToSeat: onInviteToSeat,
      onTurnMicOn: onTurnMicOn,
      onPromoteToAdmin: onPromoteToAdmin,
      onDemoteAdmin: onDemoteAdmin,
    ),
  );
}
