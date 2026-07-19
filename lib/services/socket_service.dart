import 'dart:async';
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
    if (_socket != null && _isConnected) return _socket!;

    // Coalesce concurrent connect() calls
    if (_isConnecting) {
      final c = Completer<void>();
      _connectCompleter.add(c);
      await c.future;
      return _socket!;
    }

    _isConnecting = true;
    try {
      final token = await _storage.read(key: 'accessToken');
      final uid = await _storage.read(key: 'uid');

      _socket?.dispose();
      _socket = io.io(
        AppConfig.apiBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token, 'userId': uid})
            .enableReconnection()
            .setReconnectionAttempts(double.infinity.toInt())
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(10000)
            .setRandomizationFactor(0.5)
            .setTimeout(20000)
            .disableAutoConnect()
            .build(),
      );

      _setupLifecycleListeners();
      _socket!.connect();

      // Wait up to 10s for the connection
      final timer = Timer(const Duration(seconds: 10), () {
        if (!_isConnected) {
          _completeWaiters();
        }
      });

      await Future.any([
        _socket!.onceAsync('connect'),
        Future.delayed(const Duration(seconds: 10)),
      ]).then((_) {
        timer.cancel();
        _completeWaiters();
      }).catchError((_) {
        timer.cancel();
        _completeWaiters();
      });

      return _socket!;
    } finally {
      _isConnecting = false;
    }
  }

  void _setupLifecycleListeners() {
    _socket?.on('connect', (_) {
      _isConnected = true;
      _completeWaiters();
    });

    _socket?.on('disconnect', (reason) {
      _isConnected = false;
    });

    _socket?.on('connect_error', (error) {
      _isConnected = false;
    });

    _socket?.on('reconnect', (_) {
      _isConnected = true;
    });

    _socket?.on('reconnect_failed', (_) {
      _isConnected = false;
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
