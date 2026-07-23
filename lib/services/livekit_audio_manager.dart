import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Event names emitted by LiveKitAudioManager
class LiveKitAudioEvents {
  static const String roomStateChanged = 'roomStateChanged';
  static const String roomUserUpdate = 'roomUserUpdate';
  static const String roomCommand = 'roomCommand';
  static const String soundLevelUpdate = 'soundLevelUpdate';
  static const String microphoneStateChanged = 'microphoneStateChanged';
  static const String speakerStateChanged = 'speakerStateChanged';
  static const String streamUpdate = 'streamUpdate';
  static const String activeSpeakerChanged = 'activeSpeakerChanged';
}

class RoomUpdateType {
  static const String add = 'ADD';
  static const String delete = 'DELETE';
}

/// LiveKit Real-Time Audio Room Manager for Flutter.
/// Full implementation mirroring the React Native LiveKitAudioManager.js
class LiveKitAudioManager {
  static final LiveKitAudioManager _instance = LiveKitAudioManager._internal();
  factory LiveKitAudioManager() => _instance;
  LiveKitAudioManager._internal();

  // ── State ──────────────────────────────────────────────────────────────────
  Room? _room;

  /// Exposed for providers that need to read raw participant/track state.
  Room? get room => _room;

  bool isInitialized = false;
  String? currentRoomId;
  String? currentUserId;
  String? currentUserName;
  bool isConnected = false;
  bool isPublishing = false;
  bool isPublishingInProgress = false;
  bool isMuted = true;
  int currentSeatIndex = -1;
  String audioOutputMode = 'speaker';
  bool isBluetoothAvailable = false;

  bool _destroyed = false;
  bool _isTearingDown = false;
  bool _isReconnecting = false;

  StreamSubscription<List<MediaDevice>>? _deviceChangeSub;

  EventsListener<RoomEvent>? _roomEventsListener;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  void _emit(String event, Map<String, dynamic> data) {
    if (!_eventController.isClosed) {
      _eventController.add({'event': event, ...data});
    }
  }

  // ── prepareConnection ──────────────────────────────────────────────────────
  void prepareConnection(String url) {
    if (kDebugMode) {
      print('[LiveKitAudioManager] Pre-warming LiveKit WS connection to $url');
    }
    // Dart SDK does not expose prepareConnection — no-op.
  }

  // ── Bluetooth detection ────────────────────────────────────────────────────
  static bool _isBluetoothDevice(MediaDevice d) {
    final label = d.label.toLowerCase();
    return label.contains('bluetooth') || label.contains('bt ') || label.contains(' bt');
  }

  Future<void> refreshBluetoothAvailability() async {
    try {
      final devices = await Hardware.instance.enumerateDevices();
      final hasBt = devices.any(_isBluetoothDevice);
      if (hasBt != isBluetoothAvailable) {
        isBluetoothAvailable = hasBt;
        _emit(LiveKitAudioEvents.speakerStateChanged, {
          'enabled': audioOutputMode == 'speaker',
          'mode': audioOutputMode,
          'bluetoothAvailable': hasBt,
        });
      }
    } catch (_) {}
  }

  void startDeviceMonitoring() {
    _deviceChangeSub?.cancel();
    refreshBluetoothAvailability();
    _deviceChangeSub = Hardware.instance.onDeviceChange.stream.listen((devices) {
      final hasBt = devices.any(_isBluetoothDevice);
      if (hasBt != isBluetoothAvailable) {
        isBluetoothAvailable = hasBt;
        // If BT disconnected while using BT mode, fall back to speaker
        if (!hasBt && audioOutputMode == 'bluetooth') {
          setAudioOutputMode('speaker');
        }
        _emit(LiveKitAudioEvents.speakerStateChanged, {
          'enabled': audioOutputMode == 'speaker',
          'mode': audioOutputMode,
          'bluetoothAvailable': hasBt,
        });
      }
    });
  }

  void stopDeviceMonitoring() {
    _deviceChangeSub?.cancel();
    _deviceChangeSub = null;
  }

  // ── joinRoom ───────────────────────────────────────────────────────────────
  Future<bool> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
    required String token,
    required String livekitUrl,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    _destroyed = false;

    try {
      // Disconnect any existing room
      if (_room != null) {
        _isTearingDown = true;
        try { await _room!.disconnect(); } catch (_) {}
        _teardownRoom();
        _isTearingDown = false;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (livekitUrl.isEmpty) throw Exception('LiveKit URL is empty.');
      if (token.isEmpty) throw Exception('LiveKit token is empty.');

      // Build RTCConfiguration with TURN ice servers if provided
      RTCConfiguration rtcConfig = const RTCConfiguration();
      if (iceServers != null && iceServers.isNotEmpty) {
        rtcConfig = RTCConfiguration(
          iceServers: iceServers.map((s) {
            final urls = s['urls'];
            return RTCIceServer(
              urls: urls is List
                  ? List<String>.from(urls)
                  : [urls.toString()],
              username: s['username']?.toString(),
              credential: s['credential']?.toString(),
            );
          }).toList(),
        );
      }

      // Create Room with audio-focused settings
      _room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: false,
          dynacast: false,
          defaultAudioPublishOptions: const AudioPublishOptions(
            dtx: true,
            audioBitrate: AudioPreset.speech,
          ),
          defaultAudioCaptureOptions: const AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        ),
      );

      _registerRoomEvents(roomId, userId);

      // Connect to LiveKit server
      await _room!.connect(
        livekitUrl,
        token,
        connectOptions: ConnectOptions(
          autoSubscribe: true,
          rtcConfiguration: rtcConfig,
        ),
      );

      // Set up data channel listener for incoming roomCommand messages
      _setupDataChannelListener(roomId);

      currentRoomId = roomId;
      currentUserId = userId;
      currentUserName = userName;
      isInitialized = true;
      isConnected = true;

      // Start monitoring audio device changes (Bluetooth detection)
      startDeviceMonitoring();

      // Emit initial track states for already-subscribed remote participants
      // (participants who were already in the room before we joined).
      for (final entry in _room!.remoteParticipants.entries) {
        final p = entry.value;
        final pub = p.getTrackPublicationBySource(TrackSource.microphone);
        if (pub != null) {
          _emit(LiveKitAudioEvents.streamUpdate, {
            'userID': p.identity,
            'isMicOn': !pub.muted,
          });
        }
      }

      if (kDebugMode) {
        print('[LiveKitAudioManager] Connected to room $roomId as $userId');
      }
      return true;
    } catch (e) {
      if (_destroyed) {
        if (kDebugMode) print('[LiveKitAudioManager] Join cancelled: $e');
        rethrow;
      }
      if (kDebugMode) print('[LiveKitAudioManager] Failed to join room: $e');
      rethrow;
    }
  }

  // ── _registerRoomEvents ────────────────────────────────────────────────────
  void _registerRoomEvents(String roomId, String myUserId) {
    final room = _room!;

    _roomEventsListener?.dispose();
    _roomEventsListener = room.createListener();

    // Connection state — watch via addListener
    room.addListener(_onRoomStateChanged);

    _roomEventsListener!
      ..on<ParticipantConnectedEvent>((event) {
        if (_isTearingDown || _isReconnecting) return;
        final p = event.participant;
        _emit(LiveKitAudioEvents.roomUserUpdate, {
          'roomID': roomId,
          'updateType': RoomUpdateType.add,
          'userList': [
            {'userID': p.identity, 'userName': p.name ?? p.identity}
          ],
        });
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        if (_isTearingDown) return;
        if (!_isReconnecting) {
          final p = event.participant;
          _emit(LiveKitAudioEvents.roomUserUpdate, {
            'roomID': roomId,
            'updateType': RoomUpdateType.delete,
            'userList': [
              {'userID': p.identity, 'userName': p.name ?? p.identity}
            ],
          });
        }
      })
      ..on<TrackSubscribedEvent>((event) {
        final track = event.track;
        final participant = event.participant;
        final publication = event.publication;
        if (track.kind == TrackType.AUDIO) {
          final isMicOn = !publication.muted;
          _emit(LiveKitAudioEvents.streamUpdate, {
            'roomID': roomId,
            'updateType': RoomUpdateType.add,
            'userID': participant.identity,
            'userName': participant.name ?? participant.identity,
            'isMicOn': isMicOn,
          });
        }
      })
      ..on<TrackMutedEvent>((event) {
        final p = event.participant;
        if (p != null && p.identity != myUserId) {
          _emit(LiveKitAudioEvents.streamUpdate, {
            'userID': p.identity,
            'isMicOn': false,
          });
        }
      })
      ..on<TrackUnmutedEvent>((event) {
        final p = event.participant;
        if (p != null && p.identity != myUserId) {
          _emit(LiveKitAudioEvents.streamUpdate, {
            'userID': p.identity,
            'isMicOn': true,
          });
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        isConnected = false;
        final reason = event.reason;
        int errorCode = 1002051;
        if (reason == DisconnectReason.roomDeleted) {
          errorCode = 1002034;
        } else if (reason == DisconnectReason.participantRemoved) {
          errorCode = 1002035;
        } else if (reason == DisconnectReason.clientInitiated) {
          return; // intentional
        }
        _emit(LiveKitAudioEvents.roomStateChanged, {
          'roomID': roomId,
          'reason': 'Logout',
          'errorCode': errorCode,
          'isReconnect': false,
        });
      })
      ..on<RoomReconnectedEvent>((_) {
        isConnected = true;
        _isReconnecting = false;
        _emit(LiveKitAudioEvents.roomStateChanged, {
          'roomID': roomId,
          'reason': 'Reconnected',
          'errorCode': 0,
          'isReconnect': true,
        });
        if (isPublishing && !_destroyed) {
          _republishAfterReconnect();
        }
      })
      ..on<RoomReconnectingEvent>((_) {
        isConnected = false;
        _isReconnecting = true;
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        // Emit the loudest active speaker (first in list, ordered by audio level)
        final loudest = event.speakers.firstOrNull;
        _emit(LiveKitAudioEvents.activeSpeakerChanged, {
          'roomID': roomId,
          'activeSpeakerUid': loudest?.identity,
        });
      });
  }

  void _onRoomStateChanged() {
    // No-op — we rely on events instead.
    // This listener is kept to satisfy Room.addListener requirements.
  }

  Future<void> _republishAfterReconnect() async {
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_destroyed && isConnected) {
        await _room?.localParticipant?.setMicrophoneEnabled(true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LiveKitAudioManager] Post-reconnect mic cycle failed: $e');
      }
    }
  }

  // ── startPublishing ────────────────────────────────────────────────────────
  Future<void> startPublishing() async {
    if (isPublishing || isPublishingInProgress) return;
    isPublishingInProgress = true;
    try {
      // setMicrophoneEnabled(true) creates a local audio track and publishes it
      await _room?.localParticipant?.setMicrophoneEnabled(true);
      isPublishing = true;
      isMuted = false;
      if (kDebugMode) print('[LiveKitAudioManager] Started publishing audio');
    } catch (e) {
      isPublishing = false;
      if (kDebugMode) print('[LiveKitAudioManager] startPublishing failed: $e');
      rethrow;
    } finally {
      isPublishingInProgress = false;
    }
  }

  // ── stopPublishing ─────────────────────────────────────────────────────────
  Future<void> stopPublishing() async {
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      await _room?.localParticipant?.unpublishAllTracks();
      isPublishing = false;
      isMuted = true;
      if (kDebugMode) print('[LiveKitAudioManager] Stopped publishing audio');
    } catch (e) {
      if (kDebugMode) print('[LiveKitAudioManager] stopPublishing failed: $e');
    }
  }

  // ── setMicrophoneEnabled ───────────────────────────────────────────────────
  Future<void> setMicrophoneEnabled(bool enabled) async {
    isMuted = !enabled;
    try {
      if (enabled && !isPublishing) {
        await startPublishing();
      } else {
        await _room?.localParticipant?.setMicrophoneEnabled(enabled);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LiveKitAudioManager] setMicrophoneEnabled failed: $e');
      }
    }
    _emit(LiveKitAudioEvents.microphoneStateChanged, {
      'enabled': enabled,
      'userId': currentUserId,
    });
  }

  // ── setSpeakerEnabled ──────────────────────────────────────────────────────
  Future<void> setSpeakerEnabled(bool enabled) async {
    audioOutputMode = enabled ? 'speaker' : 'earpiece';
    try {
      await Hardware.instance.setSpeakerphoneOn(enabled);
    } catch (e) {
      if (kDebugMode) {
        print('[LiveKitAudioManager] setSpeakerEnabled failed: $e');
      }
    }
    _emit(LiveKitAudioEvents.speakerStateChanged, {
      'enabled': enabled,
      'mode': audioOutputMode,
    });
  }

  // ── leaveRoom ─────────────────────────────────────────────────────────────
  Future<void> leaveRoom() async {
    if (!isConnected && _room == null) return;
    if (kDebugMode) print('[LiveKitAudioManager] Leaving room $currentRoomId');
    try { await stopPublishing(); } catch (_) {}
    try { await _room?.disconnect(); } catch (_) {}
    _teardownRoom();
  }

  // ── destroy ────────────────────────────────────────────────────────────────
  Future<void> destroy() async {
    _destroyed = true;
    await leaveRoom();
  }

  void _teardownRoom() {
    _roomEventsListener?.dispose();
    _roomEventsListener = null;
    _room?.removeListener(_onRoomStateChanged);
    _room?.dispose();
    _room = null;
    isConnected = false;
    isPublishing = false;
    isPublishingInProgress = false;
    isMuted = true;
    currentSeatIndex = -1;
    currentRoomId = null;
    currentUserId = null;
    currentUserName = null;
    isInitialized = false;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void setSeatIndex(int index) {
    currentSeatIndex = index;
  }

  /// Send a room command to all participants (or a specific target) via LiveKit data channel.
  /// Mirrors RN LiveKitAudioManager.sendRoomCommand().
  Future<void> sendRoomCommand(
    String command, {
    String? targetUserId,
    Map<String, dynamic>? data,
  }) async {
    if (kDebugMode) {
      print(
          '[LiveKitAudioManager] Sending command: $command to ${targetUserId ?? "everyone"} with data: $data');
    }

    final payload = json.encode({
      'type': 'roomCommand',
      'command': command,
      'senderID': currentUserId,
      'targetUserID': targetUserId,
      'data': data ?? {},
    });

    final bytes = Uint8List.fromList(utf8.encode(payload));

    try {
      if (_room?.localParticipant != null) {
        await _room!.localParticipant!.publishData(
          bytes,
          // Reliable delivery for commands (ensures they arrive even on lossy networks)
          reliable: true,
          // If targetUserId is specified, send only to that participant;
          // otherwise broadcast to all (destinationIdentities = null means everyone).
          destinationIdentities: targetUserId != null ? [targetUserId] : null,
          topic: 'roomCommand',
        );
      }
    } catch (e) {
      if (kDebugMode) print('[LiveKitAudioManager] sendRoomCommand publish error: $e');
    }

    // Also emit locally so the sender's own UI can react to self-targeted commands
    _emit(LiveKitAudioEvents.roomCommand, {
      'command': command,
      'targetUserId': targetUserId,
      'senderId': currentUserId,
      'data': data,
      'isSelfEmitted': true,
    });
  }

  /// Listen for incoming data channel messages and decode roomCommand payloads.
  void _setupDataChannelListener(String roomId) {
    _roomEventsListener!.on<DataReceivedEvent>((event) {
      try {
        final raw = utf8.decode(event.data);
        final decoded = json.decode(raw) as Map<String, dynamic>;
        if (decoded['type'] == 'roomCommand') {
          final command = decoded['command']?.toString() ?? '';
          final senderID = decoded['senderID']?.toString();
          final targetUserID = decoded['targetUserID']?.toString();
          final data = decoded['data'] as Map<String, dynamic>?;

          if (kDebugMode) {
            print('[LiveKitAudioManager] Received roomCommand: $command from $senderID');
          }

          _emit(LiveKitAudioEvents.roomCommand, {
            'command': command,
            'senderId': senderID,
            'targetUserId': targetUserID,
            'data': data,
            'isSelfEmitted': false,
          });
        }
      } catch (e) {
        // Ignore malformed data messages
        if (kDebugMode) print('[LiveKitAudioManager] DataReceived parse error: $e');
      }
    });
  }

  /// Set the local playback volume (0.0–1.0) for a remote participant.
  /// The Flutter LiveKit SDK does not expose per-track volume control —
  /// this is a no-op that emits an event so the UI stays in sync.
  void setParticipantVolume(String userId, double volume) {
    _emit('participantVolumeChanged', {
      'userID': userId,
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  /// Set audio output mode: 'speaker', 'earpiece', or 'bluetooth'.
  Future<void> setAudioOutputMode(String mode) async {
    audioOutputMode = mode;
    try {
      switch (mode) {
        case 'speaker':
          await Hardware.instance.setSpeakerphoneOn(true);
          break;
        case 'earpiece':
          await Hardware.instance.setSpeakerphoneOn(false);
          break;
        case 'bluetooth':
          // Bluetooth routing is handled by the OS — we just set speaker off
          // and let the BT device take over.
          await Hardware.instance.setSpeakerphoneOn(false);
          break;
      }
    } catch (e) {
      if (kDebugMode) print('[LiveKitAudioManager] setAudioOutputMode error: $e');
    }
    _emit(LiveKitAudioEvents.speakerStateChanged, {
      'enabled': mode == 'speaker',
      'mode': mode,
    });
  }

  /// Wait for the room to connect (with timeout)
  Future<void> waitForRoomConnection({int timeoutMs = 8000}) {
    if (isConnected) return Future.value();
    final completer = Completer<void>();
    Timer? timer;
    StreamSubscription? sub;
    timer = Timer(Duration(milliseconds: timeoutMs), () {
      sub?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Room connection timeout'));
      }
    });
    sub = _eventController.stream.listen((event) {
      if (event['event'] == LiveKitAudioEvents.roomStateChanged &&
          event['errorCode'] == 0) {
        timer?.cancel();
        sub?.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  void dispose() {
    stopDeviceMonitoring();
    _teardownRoom();
    _eventController.close();
  }
}

final liveKitAudioManager = LiveKitAudioManager();
