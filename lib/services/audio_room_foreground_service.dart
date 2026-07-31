import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Events fired from the native notification / CallKit UI to Flutter.
enum AudioRoomServiceEvent {
  /// User tapped Mute/Unmute in the Android notification or iOS CallKit UI.
  micToggle,
  /// User tapped Leave / End-call button.
  leaveRoom,
}

/// Singleton that bridges Flutter ↔ platform audio room background service.
///
/// Android: starts a foreground service with a WhatsApp-style persistent
///          notification (mic toggle + leave buttons).
/// iOS:     activates AVAudioSession (keeps audio alive in background) and
///          presents a CallKit call UI (mic mute toggle + end-call button).
class AudioRoomForegroundService {
  static final AudioRoomForegroundService _instance =
      AudioRoomForegroundService._internal();
  factory AudioRoomForegroundService() => _instance;
  AudioRoomForegroundService._internal();

  static const _methodChannel =
      MethodChannel('com.witalk/audio_room_service');
  static const _eventChannel =
      EventChannel('com.witalk/audio_room_events');

  StreamSubscription<dynamic>? _eventSub;
  final _eventController = StreamController<AudioRoomServiceEvent>.broadcast();

  /// Stream of events from the native notification / CallKit UI.
  Stream<AudioRoomServiceEvent> get events => _eventController.stream;

  bool _listening = false;

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event == 'micToggle') {
          _eventController.add(AudioRoomServiceEvent.micToggle);
        } else if (event == 'leaveRoom') {
          _eventController.add(AudioRoomServiceEvent.leaveRoom);
        }
      },
      onError: (e) {
        if (kDebugMode) print('[AudioRoomForegroundService] event error: $e');
      },
    );
  }

  /// Start / show the foreground service notification (Android) or CallKit UI (iOS).
  Future<void> startService({
    required String roomName,
    required bool isHost,
    required bool isInSeat,
    required bool isMuted,
  }) async {
    _ensureListening();
    try {
      await _methodChannel.invokeMethod('startService', {
        'roomName': roomName,
        'isHost': isHost,
        'isInSeat': isInSeat,
        'isMuted': isMuted,
      });
    } catch (e) {
      if (kDebugMode) print('[AudioRoomForegroundService] startService error: $e');
    }
  }

  /// Stop / dismiss the foreground service and CallKit UI.
  Future<void> stopService() async {
    try {
      await _methodChannel.invokeMethod('stopService');
    } catch (e) {
      if (kDebugMode) print('[AudioRoomForegroundService] stopService error: $e');
    }
    _eventSub?.cancel();
    _eventSub = null;
    _listening = false;
  }

  /// Update the notification state without re-creating it (e.g. after mic toggle or seat change).
  Future<void> updateService({
    required String roomName,
    required bool isHost,
    required bool isInSeat,
    required bool isMuted,
  }) async {
    try {
      await _methodChannel.invokeMethod('updateService', {
        'roomName': roomName,
        'isHost': isHost,
        'isInSeat': isInSeat,
        'isMuted': isMuted,
      });
    } catch (e) {
      if (kDebugMode) print('[AudioRoomForegroundService] updateService error: $e');
    }
  }
}

final audioRoomForegroundService = AudioRoomForegroundService();
