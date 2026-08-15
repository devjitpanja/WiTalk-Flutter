import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LiveGroupAvatar extends StatefulWidget {
  final String? picture;
  final double size;
  final VoidCallback? onPress;
  final Color primaryColor;

  const LiveGroupAvatar({
    super.key,
    this.picture,
    this.size = 52,
    this.onPress,
    required this.primaryColor,
  });

  @override
  State<LiveGroupAvatar> createState() => _LiveGroupAvatarState();
}

class _LiveGroupAvatarState extends State<LiveGroupAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _ring1Controller;
  late final AnimationController _ring2Controller;
  late final Animation<double> _ring1Scale;
  late final Animation<double> _ring1Opacity;
  late final Animation<double> _ring2Scale;
  late final Animation<double> _ring2Opacity;

  static const Color _liveRed = Color(0xFFFF3B30);

  @override
  void initState() {
    super.initState();

    _ring1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _ring2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _loopWithPause(_ring1Controller);
    // Stagger ring2 by 1400ms
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _loopWithPause(_ring2Controller);
    });

    _ring1Scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _ring1Controller, curve: Curves.easeOut),
    );
    _ring1Opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _ring1Controller, curve: Curves.easeOut),
    );

    _ring2Scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _ring2Controller, curve: Curves.easeOut),
    );
    _ring2Opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _ring2Controller, curve: Curves.easeOut),
    );
  }

  Future<void> _loopWithPause(AnimationController controller) async {
    while (mounted) {
      await controller.forward(from: 0.0);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) break;
    }
  }

  @override
  void dispose() {
    _ring1Controller.dispose();
    _ring2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // ring sits just outside avatar; max scale 1.18 → tight pulse
    final ringSize = size + 8.0;
    // OverflowBox uncouples visual size from layout size — rings don't clip ancestors
    final overflowSize = ringSize * 1.22;

    return GestureDetector(
      onTap: widget.onPress,
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          maxWidth: overflowSize,
          maxHeight: overflowSize,
          child: SizedBox(
            width: overflowSize,
            height: overflowSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Ring 1
                AnimatedBuilder(
                  animation: _ring1Controller,
                  builder: (_, _) => Transform.scale(
                    scale: _ring1Scale.value,
                    child: Opacity(
                      opacity: _ring1Opacity.value,
                      child: Container(
                        width: ringSize,
                        height: ringSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _liveRed, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                ),
                // Ring 2
                AnimatedBuilder(
                  animation: _ring2Controller,
                  builder: (_, _) => Transform.scale(
                    scale: _ring2Scale.value,
                    child: Opacity(
                      opacity: _ring2Opacity.value,
                      child: Container(
                        width: ringSize,
                        height: ringSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _liveRed, width: 2.5),
                        ),
                      ),
                    ),
                  ),
                ),
                // Avatar
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _liveRed, width: 2.5),
                    color: widget.primaryColor,
                  ),
                  child: ClipOval(
                    child: widget.picture != null
                        ? CachedNetworkImage(
                            imageUrl: widget.picture!,
                            fit: BoxFit.cover,
                            width: size,
                            height: size,
                          )
                        : Icon(
                            Icons.group,
                            color: Colors.white,
                            size: size * 0.54,
                          ),
                  ),
                ),
                // Mic badge — offset to avatar bottom-right corner
                Positioned(
                  bottom: (overflowSize - size) / 2 - 2,
                  right: (overflowSize - size) / 2 - 2,
                  child: _MicBadge(size: size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MicBadge extends StatelessWidget {
  final double size;

  const _MicBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    final badgeSize = (size * 0.38).roundToDouble();
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFF3B30),
        border: Border.fromBorderSide(
          BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
      child: Icon(
        Icons.mic,
        color: Colors.white,
        size: badgeSize * 0.6,
      ),
    );
  }
}
