import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../utils/storage.dart';

// Full socket service — manages the Socket.IO connection lifecycle.
// Three namespaces mirror the RN architecture:
//   /chat            — private DMs, presence, conversations
//   /group-chat      — all group messaging events
//   /channel         — channel real-time updates (channel_new_message)
//   /audio-room-chat — audio room events
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  io.Socket? _groupSocket;
  io.Socket? _channelSocket;
  io.Socket? _audioRoomSocket;

  // Stored audio-room join params — re-emitted on every reconnect
  Map<String, dynamic>? _audioRoomJoinParams;

  // Stored channel join params — re-emitted on every reconnect
  Map<String, dynamic>? _channelJoinParams;

  final _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  bool _isConnected = false;
  bool _isConnecting = false;

  final _connectCompleter = <Completer<void>>[];

  io.Socket? get socket => _socket;
  io.Socket? get groupSocket => _groupSocket;
  io.Socket? get channelSocket => _channelSocket;
  io.Socket? get audioRoomSocket => _audioRoomSocket;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  // ── Connect ────────────────────────────────────────────────────────────────
  Future<io.Socket> connect() async {
    debugPrint('[SOCKET] connect() called — already connected: $_isConnected, connecting: $_isConnecting');
    if (_socket != null && _isConnected) {
      debugPrint('[SOCKET] Reusing existing connected socket');
      return _socket!;
    }

    // Coalesce concurrent connect() calls
    if (_isConnecting) {
      debugPrint('[SOCKET] Already connecting, waiting...');
      final c = Completer<void>();
      _connectCompleter.add(c);
      await c.future;
      return _socket!;
    }

    _isConnecting = true;
    try {
      final token = await AppStorage.getAccessToken();
      final rawUid = await AppStorage.get('uid');
      final uid = rawUid?.toString();
      final chatUrl = '${AppConfig.apiBaseUrl}/chat';
      final groupUrl = '${AppConfig.apiBaseUrl}/group-chat';
      final channelUrl = '${AppConfig.apiBaseUrl}/channel';
      final audioRoomUrl = '${AppConfig.apiBaseUrl}/audio-room-chat';

      debugPrint('[SOCKET] Connecting to: $chatUrl');
      debugPrint('[SOCKET] uid from AppStorage: $uid');
      debugPrint('[SOCKET] token present: ${token != null && token.isNotEmpty}');

      // Store channel join params so they can be re-emitted on reconnect
      _channelJoinParams = {'userId': uid, 'token': token};

      // ── /chat namespace ──────────────────────────────────────────────────
      _socket?.dispose();
      _socket = io.io(
        chatUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token, 'userId': uid})
            .enableReconnection()
            .setReconnectionAttempts(99999)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(10000)
            .setRandomizationFactor(0.5)
            .setTimeout(20000)
            .disableAutoConnect()
            .build(),
      );
      _setupLifecycleListeners(uid);
      _socket!.connect();

      // ── /group-chat namespace ────────────────────────────────────────────
      _groupSocket?.dispose();
      _groupSocket = io.io(
        groupUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token, 'userId': uid})
            .enableReconnection()
            .setReconnectionAttempts(99999)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(10000)
            .setRandomizationFactor(0.5)
            .setTimeout(20000)
            .disableAutoConnect()
            .build(),
      );
      _setupGroupLifecycleListeners(uid);
      _groupSocket!.connect();

      // ── /channel namespace ──────────────────────────────────────────────
      _channelSocket?.dispose();
      _channelSocket = io.io(
        channelUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionAttempts(99999)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(10000)
            .setRandomizationFactor(0.5)
            .setTimeout(20000)
            .disableAutoConnect()
            .build(),
      );
      _setupChannelLifecycleListeners(uid, token);
      _channelSocket!.connect();

      // ── /audio-room-chat namespace ─────────────────────────────────────────
      _audioRoomSocket?.dispose();
      _audioRoomSocket = io.io(
        audioRoomUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token, 'userId': uid})
            .enableReconnection()
            .setReconnectionAttempts(99999)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(10000)
            .setRandomizationFactor(0.5)
            .setTimeout(20000)
            .disableAutoConnect()
            .build(),
      );
      _setupAudioRoomLifecycleListeners(uid);
      _audioRoomSocket!.connect();

      // Wait up to 10s for the /chat connection
      final timer = Timer(const Duration(seconds: 10), () {
        if (!_isConnected) {
          debugPrint('[SOCKET] ⚠️ Connect timeout after 10s — _isConnected=$_isConnected');
          _completeWaiters();
        }
      });

      await Future.any([
        _socket!.onceAsync('connect'),
        Future.delayed(const Duration(seconds: 10)),
      ]).then((_) {
        timer.cancel();
        debugPrint('[SOCKET] connect() future resolved — _isConnected=$_isConnected');
        _completeWaiters();
      }).catchError((e) {
        timer.cancel();
        debugPrint('[SOCKET] connect() future error: $e');
        _completeWaiters();
      });

      return _socket!;
    } finally {
      _isConnecting = false;
    }
  }

  void _setupLifecycleListeners(String? uid) {
    _socket?.on('connect', (_) {
      _isConnected = true;
      debugPrint('[SOCKET] ✅ Connected! socket.id=${_socket?.id}  namespace=${_socket?.nsp}');
      if (uid != null) {
        debugPrint('[SOCKET] Emitting join with uid=$uid');
        _socket?.emit('join', uid);
      } else {
        debugPrint('[SOCKET] ⚠️ uid is null — skipping join emit!');
      }
      _completeWaiters();
    });

    _socket?.on('join_success', (data) {
      debugPrint('[SOCKET] ✅ join_success received: $data');
    });

    _socket?.on('disconnect', (reason) {
      _isConnected = false;
      debugPrint('[SOCKET] ❌ Disconnected, reason: $reason');
    });

    _socket?.on('connect_error', (error) {
      _isConnected = false;
      debugPrint('[SOCKET] ❌ connect_error: $error');
    });

    _socket?.on('error', (error) {
      debugPrint('[SOCKET] ❌ Server error event: $error');
    });

    _socket?.on('message_error', (data) {
      debugPrint('[SOCKET] ❌ message_error: $data');
    });

    _socket?.on('reconnect', (_) {
      _isConnected = true;
      debugPrint('[SOCKET] 🔄 Reconnected — re-emitting join uid=$uid');
      if (uid != null) _socket?.emit('join', uid);
    });

    _socket?.on('reconnect_failed', (_) {
      _isConnected = false;
      debugPrint('[SOCKET] ❌ Reconnect failed');
    });
  }

  void _setupGroupLifecycleListeners(String? uid) {
    _groupSocket?.on('connect', (_) {
      debugPrint('[GROUP-SOCKET] ✅ Connected! id=${_groupSocket?.id}');
      if (uid != null) {
        _groupSocket?.emit('join', uid);
        debugPrint('[GROUP-SOCKET] Emitting join uid=$uid');
      }
    });

    _groupSocket?.on('join_success', (data) {
      debugPrint('[GROUP-SOCKET] ✅ join_success: $data');
    });

    _groupSocket?.on('disconnect', (reason) {
      debugPrint('[GROUP-SOCKET] ❌ Disconnected: $reason');
    });

    _groupSocket?.on('connect_error', (error) {
      debugPrint('[GROUP-SOCKET] ❌ connect_error: $error');
    });

    _groupSocket?.on('error', (error) {
      debugPrint('[GROUP-SOCKET] ❌ error: $error');
    });

    _groupSocket?.on('reconnect', (_) {
      debugPrint('[GROUP-SOCKET] 🔄 Reconnected — re-emitting join uid=$uid');
      if (uid != null) _groupSocket?.emit('join', uid);
    });
  }

  // ── /channel namespace lifecycle ───────────────────────────────────────────
  // Mirrors RN ChannelListScreen + AllChatsList: connects to /channel namespace,
  // emits `channel_join` on connect (and reconnect), re-using stored params.
  void _setupChannelLifecycleListeners(String? uid, String? token) {
    _channelSocket?.on('connect', (_) {
      debugPrint('[CHANNEL-SOCKET] ✅ Connected! id=${_channelSocket?.id}');
      final params = _channelJoinParams;
      if (params != null) {
        _channelSocket?.emit('channel_join', params);
        debugPrint('[CHANNEL-SOCKET] Emitting channel_join userId=${params['userId']}');
      } else if (uid != null) {
        _channelSocket?.emit('channel_join', {'userId': uid, 'token': token});
      }
    });

    _channelSocket?.on('disconnect', (reason) {
      debugPrint('[CHANNEL-SOCKET] ❌ Disconnected: $reason');
    });

    _channelSocket?.on('connect_error', (error) {
      debugPrint('[CHANNEL-SOCKET] ❌ connect_error: $error');
    });

    _channelSocket?.on('error', (error) {
      debugPrint('[CHANNEL-SOCKET] ❌ error: $error');
    });

    _channelSocket?.on('reconnect', (_) {
      debugPrint('[CHANNEL-SOCKET] 🔄 Reconnected — re-emitting channel_join uid=$uid');
      final params = _channelJoinParams;
      if (params != null) {
        _channelSocket?.emit('channel_join', params);
      }
    });
  }

  void _setupAudioRoomLifecycleListeners(String? uid) {
    _audioRoomSocket?.on('connect', (_) {
      debugPrint('[AUDIO-ROOM-SOCKET] ✅ Connected! id=${_audioRoomSocket?.id}');
      // Re-emit join with the stored params (set by emitAudioRoomJoin)
      final params = _audioRoomJoinParams;
      if (params != null) {
        _audioRoomSocket?.emit('join', [params['roomId'], params['userInfo']]);
        debugPrint('[AUDIO-ROOM-SOCKET] Re-emitting join roomId=${params['roomId']}');
      }
      // No fallback emit — server requires roomId + userId, which only exist once a room is entered
    });

    _audioRoomSocket?.on('join_success', (data) {
      debugPrint('[AUDIO-ROOM-SOCKET] ✅ join_success: $data');
    });

    _audioRoomSocket?.on('disconnect', (reason) {
      debugPrint('[AUDIO-ROOM-SOCKET] ❌ Disconnected: $reason');
    });

    _audioRoomSocket?.on('connect_error', (error) {
      debugPrint('[AUDIO-ROOM-SOCKET] ❌ connect_error: $error');
    });

    _audioRoomSocket?.on('error', (error) {
      debugPrint('[AUDIO-ROOM-SOCKET] ❌ error: $error');
    });

    _audioRoomSocket?.on('reconnect', (_) {
      debugPrint('[AUDIO-ROOM-SOCKET] 🔄 Reconnected — re-emitting join uid=$uid');
      if (uid != null) _audioRoomSocket?.emit('join', uid);
    });
  }

  void _completeWaiters() {
    final waiters = List<Completer<void>>.from(_connectCompleter);
    _connectCompleter.clear();
    for (final c in waiters) {
      if (!c.isCompleted) c.complete();
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _groupSocket?.disconnect();
    _groupSocket?.dispose();
    _groupSocket = null;
    _channelSocket?.disconnect();
    _channelSocket?.dispose();
    _channelSocket = null;
    _audioRoomSocket?.disconnect();
    _audioRoomSocket?.dispose();
    _audioRoomSocket = null;
    _isConnected = false;
    _isConnecting = false;
  }

  // ── Room management ────────────────────────────────────────────────────────
  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', conversationId);
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', conversationId);
  }

  void joinGroup(String groupId) {
    _groupSocket?.emit('join_group', {'group_id': groupId});
  }

  void leaveGroup(String groupId) {
    _groupSocket?.emit('leave_group', groupId);
  }

  // ── Emit helpers (/chat namespace) ─────────────────────────────────────────
  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
      _socket?.off(event);
    }
  }

  // ── Emit helpers (/group-chat namespace) ──────────────────────────────────
  void emitGroup(String event, [dynamic data]) {
    _groupSocket?.emit(event, data);
  }

  void onGroup(String event, Function(dynamic) handler) {
    _groupSocket?.on(event, handler);
  }

  void offGroup(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _groupSocket?.off(event, handler);
    } else {
      _groupSocket?.off(event);
    }
  }

  // ── Emit helpers (/channel namespace) ────────────────────────────────────
  void emitChannel(String event, [dynamic data]) {
    _channelSocket?.emit(event, data);
  }

  void onChannel(String event, Function(dynamic) handler) {
    _channelSocket?.on(event, handler);
  }

  void offChannel(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _channelSocket?.off(event, handler);
    } else {
      _channelSocket?.off(event);
    }
  }

  // ── Emit helpers (/audio-room-chat namespace) ──────────────────────────────

  /// Join an audio room — emits the room-join event with the correct server
  /// payload and stores params so they're re-emitted on every reconnect.
  void joinAudioRoom(String roomId, {
    required String userId,
    required String username,
    String? profilePicture,
  }) {
    _audioRoomJoinParams = {
      'roomId': roomId,
      'userInfo': {
        'userId': userId,
        'username': username,
        'profile_picture': profilePicture,
      },
    };
    _audioRoomSocket?.emit('join', [roomId, {
      'userId': userId,
      'username': username,
      'profile_picture': profilePicture,
    }]);
    debugPrint('[AUDIO-ROOM-SOCKET] Emitting join roomId=$roomId uid=$userId');
  }

  /// Clear stored join params when the user leaves a room.
  void leaveAudioRoom(String roomId) {
    _audioRoomJoinParams = null;
    _audioRoomSocket?.emit('leave_room', {'roomId': roomId});
  }

  void emitAudioRoom(String event, [dynamic data]) {
    _audioRoomSocket?.emit(event, data);
  }

  void onAudioRoom(String event, Function(dynamic) handler) {
    _audioRoomSocket?.on(event, handler);
  }

  void offAudioRoom(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _audioRoomSocket?.off(event, handler);
    } else {
      _audioRoomSocket?.off(event);
    }
  }
}

// Extension for async once
extension _SocketOnce on io.Socket {
  Future<dynamic> onceAsync(String event) {
    final completer = Completer<dynamic>();
    once(event, (data) {
      if (!completer.isCompleted) completer.complete(data);
    });
    return completer.future;
  }
}

final socketService = SocketService();
