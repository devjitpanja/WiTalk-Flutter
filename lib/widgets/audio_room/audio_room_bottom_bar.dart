import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium redesigned AudioRoomBottomBar.
/// Uses a frosted glass-style card look with proper touch targets (44dp min).
class AudioRoomBottomBar extends StatelessWidget {
  final bool isMicOn;
  final bool isMicLoading;
  final String audioOutputMode;
  final bool isHost;
  final bool isInSeat;
  final bool hasPendingRequest;
  final bool stageRequestEnabled;

  final bool hasActiveShare;

  final VoidCallback? onToggleMic;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onGoOnStage;
  final VoidCallback? onOffStage;
  final VoidCallback? onLeave;
  final VoidCallback? onMorePress;

  final TextEditingController chatController;
  final VoidCallback? onSendMessage;
  final FocusNode? chatFocusNode;

  const AudioRoomBottomBar({
    super.key,
    this.isMicOn = true,
    this.isMicLoading = false,
    this.audioOutputMode = 'speaker',
    this.isHost = false,
    this.isInSeat = false,
    this.hasPendingRequest = false,
    this.stageRequestEnabled = true,
    this.hasActiveShare = false,
    this.onToggleMic,
    this.onToggleSpeaker,
    this.onGoOnStage,
    this.onOffStage,
    this.onLeave,
    this.onMorePress,
    required this.chatController,
    this.onSendMessage,
    this.chatFocusNode,
  });

  static const _kSurface = Color(0xFF0D1017);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomPad),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
          top: BorderSide(
            color: const Color(0xFF0751DF).withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Mic (on stage) ────────────────────────────────
          if (isInSeat) ...[
            _MicButton(
              isMicOn: isMicOn,
              isLoading: isMicLoading,
              onTap: isMicLoading ? null : onToggleMic,
            ),
            const SizedBox(width: 8),
          ],

          // ── Speaker output ────────────────────────────────
          _IconBtn(
            onTap: onToggleSpeaker,
            icon: audioOutputMode == 'bluetooth'
                ? Icons.bluetooth_audio_rounded
                : audioOutputMode == 'speaker'
                    ? Icons.volume_up_rounded
                    : Icons.hearing_rounded,
            iconColor: Colors.white,
            bgColor: audioOutputMode == 'earpiece'
                ? const Color(0x2EFF9800)
                : audioOutputMode == 'bluetooth'
                    ? const Color(0x2E34C759)
                    : const Color(0x260751DF),
            borderColor: audioOutputMode == 'earpiece'
                ? const Color(0x66FF9800)
                : audioOutputMode == 'bluetooth'
                    ? const Color(0x6634C759)
                    : const Color(0x4D0751DF),
          ),
          const SizedBox(width: 8),

          // ── Chat input ────────────────────────────────────
          Expanded(child: _ChatInput(
            controller: chatController,
            focusNode: chatFocusNode,
            onSend: onSendMessage,
          )),
          const SizedBox(width: 8),

          // ── Hand raise (audience only) ────────────────────
          if (!isInSeat && stageRequestEnabled) ...[
            _HandRaiseButton(
              hasPendingRequest: hasPendingRequest,
              onTap: onGoOnStage,
            ),
            const SizedBox(width: 8),
          ],

          // ── More options ──────────────────────────────────
          _IconBtn(
            onTap: onMorePress,
            icon: Icons.grid_view_rounded,
            iconColor: Colors.white,
            bgColor: hasActiveShare ? const Color(0x2EFF3B30) : const Color(0x260751DF),
            borderColor: hasActiveShare ? const Color(0x66FF3B30) : const Color(0x4D0751DF),
          ),
          const SizedBox(width: 8),

          // ── Leave / End room ──────────────────────────────
          _IconBtn(
            onTap: onLeave,
            icon: Icons.exit_to_app_rounded,
            iconColor: const Color(0xFFFF6B6B),
            bgColor: const Color(0x26FF6B6B),
            borderColor: const Color(0x59FF6B6B),
          ),
        ],
      ),
    );
  }
}

// ── Mic button ────────────────────────────────────────────────────────────────
class _MicButton extends StatelessWidget {
  final bool isMicOn;
  final bool isLoading;
  final VoidCallback? onTap;

  const _MicButton({
    required this.isMicOn,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isMicOn ? const Color(0xFF0751DF) : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activeColor.withValues(alpha: 0.15),
          border: Border.all(
            color: activeColor.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: activeColor,
                ),
              )
            : Icon(
                isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                size: 19,
                color: isMicOn ? Colors.white : const Color(0xFFEF4444),
              ),
      ),
    );
  }
}

// ── Hand raise button ─────────────────────────────────────────────────────────
class _HandRaiseButton extends StatelessWidget {
  final bool hasPendingRequest;
  final VoidCallback? onTap;

  const _HandRaiseButton({
    required this.hasPendingRequest,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.white;
    final bg = hasPendingRequest
        ? const Color(0x2EFF9800)
        : const Color(0x260751DF);
    final border = hasPendingRequest
        ? const Color(0x66FF9800)
        : const Color(0x4D0751DF);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Icon(
          hasPendingRequest ? Icons.back_hand_rounded : Icons.back_hand_outlined,
          size: 19,
          color: color,
        ),
      ),
    );
  }
}

// ── Generic icon button ───────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _IconBtn({
    required this.onTap,
    required this.icon,
    this.iconColor = Colors.white70,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 19, color: iconColor),
      ),
    );
  }
}

// ── Chat input field ──────────────────────────────────────────────────────────
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onSend;

  const _ChatInput({
    required this.controller,
    this.focusNode,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0x140751DF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x330751DF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                color: Color(0xFFEBEBF5),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              decoration: const InputDecoration(
                hintText: 'Type...',
                hintStyle: TextStyle(
                  color: Color(0x4DFFFFFF),
                  fontSize: 13,
                  fontFamily: 'Outfit',
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              maxLength: 5000,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend?.call(),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) {
              if (val.text.trim().isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0751DF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.send_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
