import 'package:flutter/material.dart';

class AudioOutputBottomSheet extends StatelessWidget {
  final String audioOutputMode;
  final bool isBluetoothAvailable;
  final Function(String) onSelect;

  const AudioOutputBottomSheet({
    super.key,
    this.audioOutputMode = 'speaker',
    this.isBluetoothAvailable = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final modes = [
      {'key': 'speaker', 'label': 'Speaker', 'icon': Icons.volume_up, 'color': const Color(0xFF0751DF)},
      {'key': 'earpiece', 'label': 'Earpiece', 'icon': Icons.hearing, 'color': const Color(0xFFFF9800)},
      if (isBluetoothAvailable)
        {'key': 'bluetooth', 'label': 'Bluetooth', 'icon': Icons.bluetooth_audio, 'color': const Color(0xFF34C759)},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 8,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'AUDIO OUTPUT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 0.8,
              ),
            ),
          ),

          ...modes.map((mode) {
            final isActive = audioOutputMode == mode['key'];
            final color = mode['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    onSelect(mode['key'] as String);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0751DF).withOpacity(0.05),
                      border: Border.all(color: const Color(0xFF0751DF).withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          margin: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            color: color.withOpacity(isActive ? 0.3 : 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: isActive ? color : color.withOpacity(0.4)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(mode['icon'] as IconData, size: 22, color: color),
                        ),
                        Expanded(
                          child: Text(
                            mode['label'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive ? Colors.white : const Color(0xFFEBEBF5),
                            ),
                          ),
                        ),
                        if (isActive)
                          Icon(Icons.check_circle, size: 20, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

Future<void> showAudioOutputBottomSheet({
  required BuildContext context,
  String audioOutputMode = 'speaker',
  bool isBluetoothAvailable = false,
  required Function(String) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => AudioOutputBottomSheet(
      audioOutputMode: audioOutputMode,
      isBluetoothAvailable: isBluetoothAvailable,
      onSelect: onSelect,
    ),
  );
}
