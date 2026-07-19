import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../database/app_database.dart';
import 'chat_api_service.dart';

// Offline-first sync manager — Flutter equivalent of RN MessageSyncManager.js.
// Queues pending socket actions and flushes them when connectivity is restored.
class MessageSyncManager {
  static final MessageSyncManager _instance = MessageSyncManager._internal();
  factory MessageSyncManager() => _instance;
  MessageSyncManager._internal();

  bool _isInitialized = false;
  bool _isOfflineModeEnabled = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  io.Socket? _socket;
  String? _currentUserId;
  AppDatabase? _db;
  Timer? _syncTimer;

  final _statusListeners = <void Function(SyncStatus)>{};

  SyncStatus _syncStatus = const SyncStatus(
      syncing: false, pendingCount: 0, failedCount: 0);

  bool get isInitialized => _isInitialized;

  SyncStatus getSyncStatus() => _syncStatus;

  Future<void> initialize(
      io.Socket socket, String userId, AppDatabase db) async {
    if (_isInitialized) return;

    _socket = socket;
    _currentUserId = userId;
    _db = db;
    _isInitialized = true;

    _startPeriodicSync();
  }

  void setOnlineStatus(bool isOnline) {
    final wasOffline = !_isOnline;
    _isOnline = isOnline;

    if (wasOffline && isOnline) {
      // Network came back — sync will fire when socket joins (join_success)
      // or on the next 30s periodic tick
    }
  }

  // Called by the socket service when the socket reconnects and joins rooms
  Future<void> onSocketReady() async {
    if (_isOnline && _isOfflineModeEnabled && _isInitialized) {
      await syncPendingActions();
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isOnline && _isOfflineModeEnabled && _isInitialized) {
        syncPendingActions();
      }
    });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> syncPendingActions() async {
    final db = _db;
    final socket = _socket;
    if (db == null || socket == null) return;
    if (_isSyncing) return;
    if (!_isOnline || !_isOfflineModeEnabled) return;

    // Wait up to 2s for socket to be connected
    if (!socket.connected) {
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (socket.connected) break;
      }
      if (!socket.connected) return;
    }

    _isSyncing = true;
    _updateStatus(_syncStatus.copyWith(syncing: true));

    try {
      final actions = await db.chatDao.getPendingActions();
      _updateStatus(_syncStatus.copyWith(pendingCount: actions.length));

      for (final action in actions) {
        try {
          await _processPendingAction(action, socket);
          await db.chatDao.deletePendingAction(action.id);
        } catch (e) {
          await db.chatDao.incrementPendingActionRetry(
              action.id, e.toString());
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final remaining = await db.chatDao.getPendingActions();
      final failed = remaining.where((a) => a.retryCount >= 3).length;
      _updateStatus(_syncStatus.copyWith(
          pendingCount: 0, failedCount: failed, syncing: false));
    } catch (_) {
    } finally {
      _isSyncing = false;
      _updateStatus(_syncStatus.copyWith(syncing: false));
    }
  }

  Future<void> _processPendingAction(
      PendingAction action, io.Socket socket) async {
    final Map<String, dynamic> payload =
        jsonDecode(action.payload) as Map<String, dynamic>;

    switch (action.actionType) {
      case 'send_message':
        socket.emit('send_message', payload);
        break;
      case 'send_group_message':
        socket.emit('send_group_message', payload);
        break;
      case 'mark_read':
        socket.emit('mark_read', payload);
        break;
      case 'delete_message':
        socket.emit('delete_message', payload);
        break;
      case 'add_reaction':
        socket.emit('add_reaction', payload);
        break;
      case 'remove_reaction':
        socket.emit('remove_reaction', payload);
        break;
      default:
        break;
    }
  }

  void _updateStatus(SyncStatus status) {
    _syncStatus = status;
    for (final fn in _statusListeners) {
      try {
        fn(status);
      } catch (_) {}
    }
  }

  void Function() onStatusChange(void Function(SyncStatus) callback) {
    _statusListeners.add(callback);
    return () => _statusListeners.remove(callback);
  }

  Future<void> retryFailedActions() async {
    final db = _db;
    if (db == null || !_isInitialized) return;

    final actions = await db.chatDao.getPendingActions();
    for (final a in actions.where((a) => a.retryCount >= 3)) {
      await db.chatDao.resetPendingActionRetry(a.id);
    }
    await syncPendingActions();
  }

  void cleanup() {
    stopPeriodicSync();
    _socket = null;
    _isInitialized = false;
  }
}

class SyncStatus {
  final bool syncing;
  final int pendingCount;
  final int failedCount;

  const SyncStatus({
    required this.syncing,
    required this.pendingCount,
    required this.failedCount,
  });

  SyncStatus copyWith({bool? syncing, int? pendingCount, int? failedCount}) =>
      SyncStatus(
        syncing: syncing ?? this.syncing,
        pendingCount: pendingCount ?? this.pendingCount,
        failedCount: failedCount ?? this.failedCount,
      );
}

final messageSyncManager = MessageSyncManager();
