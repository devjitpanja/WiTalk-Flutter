import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pixel-perfect Flutter port of the RN AudioRoomBottomBar.
/// Background: rgba(13,16,23,0.98) / #0d1017 — dark room bar
class AudioRoomBottomBar extends StatelessWidget {
  final bool isMicOn;
  final bool isMicLoading;
  final String audioOutputMode; // 'speaker' | 'earpiece' | 'bluetooth'
  final bool isHost;
  final bool isInSeat;
  final bool hasPendingRequest; // hand-raise pending
  final bool stageRequestEnabled;

  final VoidCallback? onToggleMic;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onGoOnStage; // hand raise / request seat
  final VoidCallback? onOffStage;  // leave stage
  final VoidCallback? onLeave;
  final VoidCallback? onMorePress;

  // Chat
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFA0D1017),
        border: Border(
          top: BorderSide(color: Color(0x260751DF), width: 1),
        ),
      ),
      child: Row(
        children: [
          // ── On stage: Mic toggle ──────────────────────────
          if (isInSeat) ...[
            _buildIconButton(
              onTap: isMicLoading ? null : onToggleMic,
              icon: isMicOn ? Icons.mic : Icons.mic_off,
              iconColor: isMicOn ? Colors.white : const Color(0xFFFF3B30),
              bg: isMicOn
                  ? const Color(0x260751DF)
                  : const Color(0x2EFF3B30),
              border: isMicOn
                  ? const Color(0x4D0751DF)
                  : const Color(0x66FF3B30),
              child: isMicLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0751DF),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          // ── Speaker / Audio output ────────────────────────
          _buildIconButton(
            onTap: onToggleSpeaker,
            icon: audioOutputMode == 'bluetooth'
                ? Icons.bluetooth_audio
                : audioOutputMode == 'speaker'
                    ? Icons.volume_up
                    : Icons.hearing,
            bg: audioOutputMode == 'earpiece'
                ? const Color(0x2EFF9800)
                : audioOutputMode == 'bluetooth'
                    ? const Color(0x2E34C759)
                    : const Color(0x260751DF),
            border: audioOutputMode == 'earpiece'
                ? const Color(0x66FF9800)
                : audioOutputMode == 'bluetooth'
                    ? const Color(0x6634C759)
                    : const Color(0x4D0751DF),
          ),
          const SizedBox(width: 8),

          // ── Chat input ────────────────────────────────────
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0x140751DF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x330751DF)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: chatController,
                      focusNode: chatFocusNode,
                      style: const TextStyle(
                        color: Color(0xFFEBEBF5),
                        fontSize: 14,
                        fontFamily: 'Outfit',
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Type...',
                        hintStyle: TextStyle(
                          color: Color(0x59FFFFFF),
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      maxLength: 5000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSendMessage?.call(),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: chatController,
                    builder: (_, val, __) {
                      if (val.text.trim().isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: onSendMessage,
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0751DF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0751DF).withAlpha(100),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.send, size: 14, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Hand-raise (audience) OR Off-stage button ─────
          if (!isInSeat && stageRequestEnabled) ...[
            _buildHandRaiseButton(),
            const SizedBox(width: 8),
          ],

          // ── More options ──────────────────────────────────
          _buildIconButton(
            onTap: onMorePress,
            icon: Icons.grid_view_rounded,
            bg: const Color(0x260751DF),
            border: const Color(0x4D0751DF),
          ),
          const SizedBox(width: 8),

          // ── Leave / End room ─────────────────────────────
          _buildIconButton(
            onTap: onLeave,
            icon: Icons.exit_to_app,
            iconColor: const Color(0xFFFF6B6B),
            bg: const Color(0x26FF6B6B),
            border: const Color(0x59FF6B6B),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    VoidCallback? onTap,
    IconData? icon,
    Color iconColor = Colors.white,
    required Color bg,
    required Color border,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: border.withAlpha(60),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: child ?? (icon != null ? Icon(icon, size: 18, color: iconColor) : null),
      ),
    );
  }

  Widget _buildHandRaiseButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onGoOnStage?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasPendingRequest
              ? const Color(0x2EFF9800)
              : const Color(0x260751DF),
          border: Border.all(
            color: hasPendingRequest
                ? const Color(0x66FF9800)
                : const Color(0x4D0751DF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: hasPendingRequest
                  ? const Color(0x40FF9800)
                  : const Color(0x400751DF),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: hasPendingRequest
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF9800),
                ),
              )
            : const Text('✋', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
