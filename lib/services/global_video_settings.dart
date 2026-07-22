import 'package:shared_preferences/shared_preferences.dart';

typedef VolumeListener = void Function(bool muted);

/// Mirrors RN's GlobalVideoSettings — persists mute preference and broadcasts
/// changes to all registered PostCard instances so toggling one affects all.
class GlobalVideoSettings {
  GlobalVideoSettings._();
  static final GlobalVideoSettings instance = GlobalVideoSettings._();

  static const _key = 'videoMuted';

  bool _muted = true;
  final List<VolumeListener> _listeners = [];

  bool get muted => _muted;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _muted = prefs.getBool(_key) ?? true;
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    for (final cb in List<VolumeListener>.from(_listeners)) {
      cb(value);
    }
  }

  void addListener(VolumeListener cb) => _listeners.add(cb);
  void removeListener(VolumeListener cb) => _listeners.remove(cb);
}

final globalVideoSettings = GlobalVideoSettings.instance;
