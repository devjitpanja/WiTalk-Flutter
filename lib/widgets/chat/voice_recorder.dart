import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/theme_colors.dart';

class VoiceRecorder extends StatefulWidget {
  final void Function({required String uri, required double duration}) onSend;
  final VoidCallback onCancel;

  const VoiceRecorder({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isPaused = false;
  String? _filePath;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSub;

  // 30 bars, heights in range [4, 24]
  final List<double> _bars = List.filled(30, 4.0);

  late final AnimationController _dotCtrl;
  late final Animation<double> _dotAnim;

  static const int _maxSeconds = 300;
  static const double _barMin = 4.0;
  static const double _barMax = 24.0;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _dotAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut),
    );
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _dotCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        widget.onCancel();
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _filePath = path;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(_onAmplitude);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed.inSeconds >= _maxSeconds) _stopAndSend();
    });

    if (mounted) setState(() => _isPaused = false);
  }

  void _onAmplitude(Amplitude amp) {
    if (!mounted) return;
    // amp.current is in dB, typically -160..0. Map to bar height.
    final normalised = ((amp.current + 60) / 60).clamp(0.0, 1.0);
    final height = _barMin + normalised * (_barMax - _barMin);
    setState(() {
      _bars.removeAt(0);
      _bars.add(height);
    });
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      await _recorder.resume();
      setState(() => _isPaused = false);
    } else {
      await _recorder.pause();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    final path = await _recorder.stop();
    final elapsed = _elapsed;

    final resolvedPath = path ?? _filePath;
    if (resolvedPath == null || !File(resolvedPath).existsSync()) {
      widget.onCancel();
      return;
    }
    widget.onSend(uri: resolvedPath, duration: elapsed.inSeconds.toDouble());
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    await _recorder.stop();
    if (_filePath != null) {
      try {
        File(_filePath!).deleteSync();
      } catch (_) {}
    }
    widget.onCancel();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TOP ROW: timer + waveform
          Row(
            children: [
              Text(
                _formatDuration(_elapsed),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: c.text,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(30, (i) {
                      return Expanded(
                        child: Container(
                          margin: i < 29
                              ? const EdgeInsets.only(right: 2)
                              : EdgeInsets.zero,
                          height: _bars[i],
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // BOTTOM ROW: delete | pause/resume | send
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Delete
                SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.delete_outline, color: c.textSecondary),
                    onPressed: _cancel,
                  ),
                ),

                // Center: pause/resume
                GestureDetector(
                  onTap: _togglePause,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: _isPaused
                          ? Icon(Icons.mic, size: 28, color: const Color(0xFFFF3B30))
                          : Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Two pause bars
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF3B30),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 4,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF3B30),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                                // Pulsing red dot
                                Positioned(
                                  top: -4,
                                  right: -10,
                                  child: FadeTransition(
                                    opacity: _dotAnim,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF3B30),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                // Send
                GestureDetector(
                  onTap: _stopAndSend,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
