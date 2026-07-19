import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme/theme_colors.dart';

// Mirrors VoiceMessagePlayer.jsx
class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isMyMessage;
  final double? duration; // seconds, from media_data

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.isMyMessage,
    this.duration,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _current = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    if (widget.duration != null) {
      _total = Duration(
          milliseconds: (widget.duration! * 1000).toInt());
    }

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _current = pos);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _total = dur);
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = false;
        });
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _current = Duration.zero;
        });
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      setState(() => _isLoading = true);
      try {
        await _player.play(UrlSource(widget.audioUrl));
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trackColor = widget.isMyMessage
        ? Colors.white.withOpacity(0.3)
        : c.border;
    final progressColor =
        widget.isMyMessage ? Colors.white : c.primary;
    final iconColor =
        widget.isMyMessage ? Colors.white : c.text;

    final progress = _total.inMilliseconds > 0
        ? _current.inMilliseconds / _total.inMilliseconds
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isMyMessage
                  ? Colors.white.withOpacity(0.2)
                  : c.primary.withOpacity(0.12),
            ),
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: iconColor,
                    size: 22,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        // Waveform + progress
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WaveformProgress(
                progress: progress,
                trackColor: trackColor,
                progressColor: progressColor,
              ),
              const SizedBox(height: 2),
              Text(
                _total > Duration.zero
                    ? _formatDuration(_isPlaying ? _current : _total)
                    : '--:--',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Outfit',
                  color: widget.isMyMessage
                      ? Colors.white.withOpacity(0.7)
                      : c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaveformProgress extends StatelessWidget {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _WaveformProgress({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      return GestureDetector(
        onHorizontalDragUpdate: (_) {}, // TODO: seek
        child: CustomPaint(
          size: Size(w, 28),
          painter: _WaveformPainter(
            progress: progress.clamp(0.0, 1.0),
            trackColor: trackColor,
            progressColor: progressColor,
          ),
        ),
      );
    });
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  static const _heights = [
    0.3, 0.5, 0.8, 0.6, 0.9, 0.7, 0.4, 0.6, 0.8, 0.5,
    0.7, 0.9, 0.6, 0.4, 0.8, 0.7, 0.5, 0.3, 0.6, 0.9,
    0.7, 0.5, 0.8, 0.4, 0.6, 0.9, 0.3, 0.7, 0.5, 0.8
  ];

  const _WaveformPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barW = 3.0;
    final gap = 2.0;
    final n = _heights.length;
    final totalW = barW * n + gap * (n - 1);
    final startX = (size.width - totalW) / 2;
    final maxH = size.height;

    for (int i = 0; i < n; i++) {
      final x = startX + i * (barW + gap);
      final barH = _heights[i] * maxH;
      final y = (maxH - barH) / 2;
      final isFilled = (i / n) <= progress;
      final paint = Paint()
        ..color = isFilled ? progressColor : trackColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, barW, barH),
            const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
