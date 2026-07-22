import 'package:audioplayers/audioplayers.dart';
import 'logger.dart';

class SoundEffectService {
  static final SoundEffectService _instance = SoundEffectService._internal();
  factory SoundEffectService() => _instance;
  SoundEffectService._internal();

  bool _isEnabled = true;
  final _player = AudioPlayer();

  bool get isEnabled => _isEnabled;
  void setEnabled(bool enabled) => _isEnabled = enabled;

  Future<bool> playMessageSentSound() async {
    return _play('sounds/message_sent.mp3');
  }

  Future<bool> playMessageReceivedSound() async {
    return _play('sounds/message_received.mp3');
  }

  Future<bool> playSound(String soundName) async {
    return _play('sounds/$soundName.mp3');
  }

  Future<bool> _play(String assetPath) async {
    if (!_isEnabled) return false;
    try {
      await _player.play(AssetSource(assetPath));
      return true;
    } catch (e) {
      AppLogger.warn('Failed to play sound $assetPath', e);
      return false;
    }
  }

  void dispose() => _player.dispose();
}

final soundEffectService = SoundEffectService();
