import 'package:flutter/material.dart';

/// Pixel-perfect port of RN Pinned Rules Banner.
/// Rendered when the room has rules and has not been dismissed.
class RoomRulesBanner extends StatefulWidget {
  final String rulesText;
  final VoidCallback onDismiss;

  const RoomRulesBanner({
    super.key,
    required this.rulesText,
    required this.onDismiss,
  });

  @override
  State<RoomRulesBanner> createState() => _RoomRulesBannerState();
}

class _RoomRulesBannerState extends State<RoomRulesBanner> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0FFFDF66), // rgba(255, 209, 102, 0.06)
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0x38FFD166), // rgba(255, 209, 102, 0.22)
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gavel,
                      size: 14,
                      color: Color(0xFFFFD166),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Room Rules',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFD166),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFD166),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            size: 9,
                            color: Color(0xB2FFD166),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'PINNED',
                            style: TextStyle(
                              fontSize: 8,
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              color: Color(0xB2FFD166),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: const Color(0x99FFD166),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0x80FFD166),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Rules text body
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _isExpanded ? 150.0 : 36.0,
            ),
            child: SingleChildScrollView(
              physics: _isExpanded
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: Text(
                widget.rulesText,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w400,
                  color: Color(0xBFFFEB14),
                  height: 1.4,
                ),
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
