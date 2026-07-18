import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

typedef MessageCallback = void Function(Map<String, dynamic> data);
typedef TypingCallback = void Function(String conversationId, String userId, bool isTyping);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final _storage = const FlutterSecureStorage();
  bool _isConnected = false;

  final Map<String, List<MessageCallback>> _messageListeners = {};
  final Map<String, List<TypingCallback>> _typingListeners = {};
  final List<VoidCallback> _connectListeners = [];

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    final token = await _storage.read(key: 'access_token');
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');

    _socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token, 'userId': uid})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.on('connect', (_) {
      _isConnected = true;
      for (final cb in _connectListeners) cb();
    });

    _socket!.on('disconnect', (_) => _isConnected = false);

    _socket!.on('new_message', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      final convId = d['conversationId'] as String? ?? '';
      _messageListeners[convId]?.forEach((cb) => cb(d));
      _messageListeners['*']?.forEach((cb) => cb(d));
    });

    _socket!.on('new_group_message', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      final groupId = d['groupId'] as String? ?? '';
      _messageListeners[groupId]?.forEach((cb) => cb(d));
      _messageListeners['*']?.forEach((cb) => cb(d));
    });

    _socket!.on('typing', (data) {
      final d = Map<String, dynamic>.from(data as Map);
      final convId = d['conversationId'] as String? ?? '';
      final userId = d['userId'] as String? ?? '';
      final isTyping = d['isTyping'] == true;
      _typingListeners[convId]?.forEach((cb) => cb(convId, userId, isTyping));
    });

    _socket!.on('user_online', (data) {});
    _socket!.on('user_offline', (data) {});
    _socket!.on('message_read', (data) {});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void joinConversation(String conversationId) {
    _socket?.emit('join_chat', {'chatId': conversationId});
  }

  void joinGroup(String groupId) {
    _socket?.emit('join_group', {'groupId': groupId});
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave_chat', {'chatId': conversationId});
  }

  void sendTyping(String conversationId, bool isTyping) {
    _socket?.emit('typing', {'conversationId': conversationId, 'isTyping': isTyping});
  }

  void markRead(String conversationId, String messageId) {
    _socket?.emit('message_read', {'conversationId': conversationId, 'messageId': messageId});
  }

  void onMessage(String conversationId, MessageCallback callback) {
    _messageListeners.putIfAbsent(conversationId, () => []).add(callback);
  }

  void onAnyMessage(MessageCallback callback) {
    _messageListeners.putIfAbsent('*', () => []).add(callback);
  }

  void onTyping(String conversationId, TypingCallback callback) {
    _typingListeners.putIfAbsent(conversationId, () => []).add(callback);
  }

  void offMessage(String conversationId, MessageCallback callback) {
    _messageListeners[conversationId]?.remove(callback);
  }

  void offTyping(String conversationId, TypingCallback callback) {
    _typingListeners[conversationId]?.remove(callback);
  }

  void onConnect(VoidCallback callback) => _connectListeners.add(callback);
}

typedef VoidCallback = void Function();

final socketService = SocketService();
