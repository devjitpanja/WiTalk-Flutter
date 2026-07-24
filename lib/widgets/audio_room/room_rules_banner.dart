import 'package:flutter/material.dart';

/// Premium redesigned Room Rules Banner.
/// Collapsible pinned rules card with amber/gold accent.
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
  void initState() {
    super.initState();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0x0CFFD166),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x3AFFD166),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, size: 13, color: Color(0xFFFFD166)),
                  const SizedBox(width: 6),
                  const Text(
                    'Room Rules',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFD166),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFD166),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded, size: 8, color: Color(0xAAFFD166)),
                        SizedBox(width: 3),
                        Text(
                          'PINNED',
                          style: TextStyle(
                            fontSize: 7,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            color: Color(0xAAFFD166),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0x99FFD166),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Color(0x80FFD166),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Rules text (always shown, clipped when collapsed) ──
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                widget.rulesText,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w400,
                  color: Color(0xCCFFEB14),
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            secondChild: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Text(
                  widget.rulesText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w400,
                    color: Color(0xCCFFEB14),
                    height: 1.5,
                  ),
                ),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
