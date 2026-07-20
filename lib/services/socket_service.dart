import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

// Full socket service — manages the Socket.IO connection lifecycle.
// The ChatNotifier in chat_provider.dart registers its own event handlers
// on the shared socket. This service just exposes the socket instance
// and handles auth, reconnection, and room management.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  bool _isConnected = false;
  bool _isConnecting = false;

  final _connectCompleter = <Completer<void>>[];

  io.Socket? get socket => _socket;
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
      final token = await _storage.read(key: 'accessToken');
      final uid = await _storage.read(key: 'uid');
      final url = '${AppConfig.apiBaseUrl}/chat';

      debugPrint('[SOCKET] Connecting to: $url');
      debugPrint('[SOCKET] uid from storage: $uid');
      debugPrint('[SOCKET] token present: ${token != null && token.isNotEmpty}');

      _socket?.dispose();
      _socket = io.io(
        url,
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

      // Wait up to 10s for the connection
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
      // Emit join with userId so the backend adds this socket to user:${uid}
      // and all conversation rooms — required for message_sent/new_message routing.
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
      if (uid != null) {
        _socket?.emit('join', uid);
      }
    });

    _socket?.on('reconnect_failed', (_) {
      _isConnected = false;
      debugPrint('[SOCKET] ❌ Reconnect failed');
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
    _socket?.emit('join_group', {'group_id': groupId});
  }

  void leaveGroup(String groupId) {
    _socket?.emit('leave_group', {'group_id': groupId});
  }

  // ── Emit helpers ───────────────────────────────────────────────────────────
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
