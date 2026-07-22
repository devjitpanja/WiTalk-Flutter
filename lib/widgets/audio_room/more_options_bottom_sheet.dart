import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MoreOptionsBottomSheet extends StatelessWidget {
  final bool isHost;
  final bool isScreenSharing;
  final bool isCameraSharing;
  final int activeCameraCount;
  final VoidCallback? onToggleScreenShare;
  final VoidCallback? onToggleCameraShare;
  final bool screenShareBlocked;
  final bool cameraBlocked;
  final bool youtubeBlocked;
  final bool screenShareFeatureEnabled;
  final bool videoShareFeatureEnabled;
  final bool youtubeFeatureEnabled;
  final bool chatgptFeatureEnabled;
  final bool googleAiFeatureEnabled;
  final VoidCallback? onRoomSettings;
  final bool isYoutubeActive;
  final VoidCallback? onYoutubeVideo;
  final VoidCallback? onChatGPT;
  final VoidCallback? onGoogleAI;

  const MoreOptionsBottomSheet({
    super.key,
    this.isHost = false,
    this.isScreenSharing = false,
    this.isCameraSharing = false,
    this.activeCameraCount = 0,
    this.onToggleScreenShare,
    this.onToggleCameraShare,
    this.screenShareBlocked = false,
    this.cameraBlocked = false,
    this.youtubeBlocked = false,
    this.screenShareFeatureEnabled = true,
    this.videoShareFeatureEnabled = true,
    this.youtubeFeatureEnabled = true,
    this.chatgptFeatureEnabled = true,
    this.googleAiFeatureEnabled = true,
    this.onRoomSettings,
    this.isYoutubeActive = false,
    this.onYoutubeVideo,
    this.onChatGPT,
    this.onGoogleAI,
  });

  @override
  Widget build(BuildContext context) {
    final cameraCapacityFull = !isCameraSharing && activeCameraCount >= 2;
    final cameraShareBlocked = cameraCapacityFull || (!isCameraSharing && cameraBlocked) || (!isCameraSharing && !videoShareFeatureEnabled);
    final screenShareDisabled = (!isScreenSharing && screenShareBlocked) || (!isScreenSharing && !screenShareFeatureEnabled);
    final youtubeShareBlocked = (!isYoutubeActive && youtubeBlocked) || (!isYoutubeActive && !youtubeFeatureEnabled);
    final youtubeDisabledByAdmin = !isYoutubeActive && !youtubeFeatureEnabled;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1017),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: const Color(0xFF0751DF).withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF0751DF).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Row(
            children: [
              Icon(
                Icons.more_horiz,
                color: const Color(0xFF828CF8).withOpacity(0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'More Options',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC8D2FF).withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Options (Host only)
          if (isHost) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Share Screen
                Expanded(
                  child: _buildOptionButton(
                    context: context,
                    icon: isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                    label: isScreenSharing ? 'Stop Sharing' : 'Share Screen',
                    isActive: isScreenSharing,
                    isDisabled: screenShareDisabled,
                    activeColor: const Color(0xFFFF3B30),
                    defaultColor: const Color(0xFF0751DF),
                    onTap: screenShareDisabled ? null : () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 200), onToggleScreenShare);
                    },
                    subLabel: (!isScreenSharing && !screenShareFeatureEnabled)
                        ? 'Admin disabled'
                        : (!isScreenSharing && screenShareFeatureEnabled && screenShareBlocked)
                            ? ((isCameraSharing || activeCameraCount > 0) ? 'Camera active' : 'YouTube active')
                            : null,
                  ),
                ),
                const SizedBox(width: 14),
                // Share Camera
                Expanded(
                  child: _buildOptionButton(
                    context: context,
                    icon: isCameraSharing ? Icons.videocam_off : Icons.videocam,
                    label: isCameraSharing ? 'Stop Camera' : 'Share Camera',
                    isActive: isCameraSharing,
                    isDisabled: cameraShareBlocked,
                    activeColor: const Color(0xFFFF3B30),
                    defaultColor: const Color(0xFF0751DF),
                    onTap: cameraShareBlocked ? null : () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 200), onToggleCameraShare);
                    },
                    subLabel: cameraCapacityFull
                        ? 'Full (2/2)'
                        : (!isCameraSharing && !videoShareFeatureEnabled)
                            ? 'Admin disabled'
                            : (!isCameraSharing && videoShareFeatureEnabled && cameraBlocked && !cameraCapacityFull)
                                ? (isScreenSharing ? 'Screen active' : 'YouTube active')
                                : null,
                  ),
                ),
                const SizedBox(width: 14),
                // YouTube
                Expanded(
                  child: _buildOptionButton(
                    context: context,
                    icon: Icons.smart_display,
                    label: isYoutubeActive ? 'Stop Video' : 'YouTube',
                    isActive: isYoutubeActive,
                    isDisabled: youtubeShareBlocked,
                    activeColor: const Color(0xFFFF3B30),
                    defaultColor: const Color(0xFF0751DF),
                    onTap: youtubeShareBlocked ? null : () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 200), onYoutubeVideo);
                    },
                    subLabel: (!isYoutubeActive && youtubeShareBlocked)
                        ? (youtubeDisabledByAdmin ? 'Admin disabled' : (isScreenSharing ? 'Screen active' : 'Camera active'))
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // AI Options
          Row(
            children: [
              Expanded(
                child: _buildAiButton(
                  context: context,
                  icon: Icons.psychology,
                  label: 'ChatGPT',
                  iconColor: const Color(0xFF10A37F),
                  isDisabled: !chatgptFeatureEnabled,
                  onTap: !chatgptFeatureEnabled ? null : () {
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 200), onChatGPT);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAiButton(
                  context: context,
                  icon: Icons.search,
                  label: 'Google AI',
                  iconColor: const Color(0xFF4285F4),
                  isDisabled: !googleAiFeatureEnabled,
                  onTap: !googleAiFeatureEnabled ? null : () {
                    Navigator.pop(context);
                    Future.delayed(const Duration(milliseconds: 200), onGoogleAI);
                  },
                ),
              ),
            ],
          ),

          // Settings
          if (isHost) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 200), onRoomSettings);
                },
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white.withOpacity(0.1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0751DF).withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0751DF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Room Settings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFC8D2FF).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (activeCameraCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  '$activeCameraCount/2 camera ${activeCameraCount == 1 ? 'stream' : 'streams'} active',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF828CF8).withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDisabled,
    required Color activeColor,
    required Color defaultColor,
    required VoidCallback? onTap,
    String? subLabel,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.08)
                : Colors.white.withOpacity(isDisabled ? 0.02 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? activeColor.withOpacity(0.3)
                  : Colors.white.withOpacity(isDisabled ? 0.02 : 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? activeColor.withOpacity(0.15)
                          : isDisabled
                              ? Colors.white.withOpacity(0.05)
                              : defaultColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? activeColor.withOpacity(0.4)
                            : isDisabled
                                ? Colors.white.withOpacity(0.1)
                                : defaultColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isActive
                          ? activeColor
                          : isDisabled
                              ? Colors.white.withOpacity(0.3)
                              : Colors.white,
                      size: 24,
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 2, right: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? const Color(0xFFFF6B6B)
                      : isDisabled
                          ? const Color(0xFFC8D2FF).withOpacity(0.35)
                          : const Color(0xFFC8D2FF).withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              if (subLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFC8D2FF).withOpacity(0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color iconColor,
    required bool isDisabled,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: iconColor.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isDisabled ? 0.02 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDisabled ? Colors.white.withOpacity(0.03) : iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDisabled ? Colors.white.withOpacity(0.08) : iconColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isDisabled ? Colors.white.withOpacity(0.3) : iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDisabled
                          ? const Color(0xFFC8D2FF).withOpacity(0.4)
                          : const Color(0xFFC8D2FF).withOpacity(0.8),
                    ),
                    children: [
                      if (isDisabled)
                        TextSpan(
                          text: ' (Disabled)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFC8D2FF).withOpacity(0.3),
                          ),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMoreOptionsBottomSheet({
  required BuildContext context,
  bool isHost = false,
  bool isScreenSharing = false,
  bool isCameraSharing = false,
  int activeCameraCount = 0,
  VoidCallback? onToggleScreenShare,
  VoidCallback? onToggleCameraShare,
  bool screenShareBlocked = false,
  bool cameraBlocked = false,
  bool youtubeBlocked = false,
  bool screenShareFeatureEnabled = true,
  bool videoShareFeatureEnabled = true,
  bool youtubeFeatureEnabled = true,
  bool chatgptFeatureEnabled = true,
  bool googleAiFeatureEnabled = true,
  VoidCallback? onRoomSettings,
  bool isYoutubeActive = false,
  VoidCallback? onYoutubeVideo,
  VoidCallback? onChatGPT,
  VoidCallback? onGoogleAI,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MoreOptionsBottomSheet(
      isHost: isHost,
      isScreenSharing: isScreenSharing,
      isCameraSharing: isCameraSharing,
      activeCameraCount: activeCameraCount,
      onToggleScreenShare: onToggleScreenShare,
      onToggleCameraShare: onToggleCameraShare,
      screenShareBlocked: screenShareBlocked,
      cameraBlocked: cameraBlocked,
      youtubeBlocked: youtubeBlocked,
      screenShareFeatureEnabled: screenShareFeatureEnabled,
      videoShareFeatureEnabled: videoShareFeatureEnabled,
      youtubeFeatureEnabled: youtubeFeatureEnabled,
      chatgptFeatureEnabled: chatgptFeatureEnabled,
      googleAiFeatureEnabled: googleAiFeatureEnabled,
      onRoomSettings: onRoomSettings,
      isYoutubeActive: isYoutubeActive,
      onYoutubeVideo: onYoutubeVideo,
      onChatGPT: onChatGPT,
      onGoogleAI: onGoogleAI,
    ),
  );
}
