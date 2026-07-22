import 'package:flutter/foundation.dart';

class AudioRoomForegroundService {
  static final AudioRoomForegroundService _instance = AudioRoomForegroundService._internal();
  factory AudioRoomForegroundService() => _instance;
  AudioRoomForegroundService._internal();

  Future<void> startService(String roomTitle) async {
    if (kDebugMode) print('[AudioRoomForegroundService] Started foreground notification for $roomTitle');
  }

  Future<void> stopService() async {
    if (kDebugMode) print('[AudioRoomForegroundService] Stopped foreground notification');
  }
}

final audioRoomForegroundService = AudioRoomForegroundService();
