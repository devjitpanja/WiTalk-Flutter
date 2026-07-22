import 'dart:async';

/// SeatManager — manages seat array, locked seats, seat requests and invitations.
///
/// This is a direct port of the React Native SeatManager.js component.
/// It is a pure data-management class — the server (via seat_state socket events)
/// is the only authoritative source of seat truth. This class tracks local UI state
/// only (pending requests, invitations) and exposes read-only helpers.
class SeatManager {
  // ── Core seat state (server-authoritative) ─────────────────────────────────
  List<String?> seats;
  Set<int> lockedSeats;

  // ── Configuration ──────────────────────────────────────────────────────────
  bool isHost;
  bool stageRequestEnabled;
  int maxSeats;
  int maxAllowedSeats;

  // ── Server sync guard ──────────────────────────────────────────────────────
  /// Set to true when the server sends the first authoritative seat_state event.
  /// Prevents users from tapping seats before the initial state is received.
  bool serverSeatStateReceived;

  // ── UI-only state (local estimates, cleared on seat_state from server) ─────
  /// userID → { seatIndex, timestamp, userName }
  Map<String, Map<String, dynamic>> seatRequests;

  /// userID → { seatIndex, timestamp }
  Map<String, Map<String, dynamic>> seatInvitations;

  /// Local user's own pending request — cleared when accepted or rejected.
  Map<String, dynamic>? pendingOwnRequest;

  // ── Event stream ───────────────────────────────────────────────────────────
  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  SeatManager({
    int maxSeats = 12,
    int maxAllowedSeats = 12,
  })  : maxSeats = maxSeats,
        maxAllowedSeats = maxAllowedSeats,
        seats = List.filled(maxSeats, null),
        lockedSeats = {},
        seatRequests = {},
        seatInvitations = {},
        isHost = false,
        stageRequestEnabled = false,
        serverSeatStateReceived = false,
        pendingOwnRequest = null;

  // ── Read-only helpers ──────────────────────────────────────────────────────

  /// Returns the first available seat index (>= 1), or -1 if all full/locked.
  int findAvailableSeat() {
    for (int i = 1; i < maxSeats; i++) {
      if (seats[i] == null && !lockedSeats.contains(i)) return i;
    }
    return -1;
  }

  /// Returns true if the seat at [seatIndex] is both empty and not locked.
  bool isSeatAvailable(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return false;
    return seats[seatIndex] == null && !lockedSeats.contains(seatIndex);
  }

  /// Returns true if the seat at [seatIndex] is locked.
  bool isSeatLocked(int seatIndex) {
    return lockedSeats.contains(seatIndex);
  }

  /// Returns the seat index occupied by [userId], or -1 if not in a seat.
  int getSeatForUser(String userId) {
    if (userId.isEmpty) return -1;
    final target = userId.trim();
    for (int i = 0; i < seats.length; i++) {
      final item = seats[i];
      if (item != null && item.trim().isNotEmpty && item.trim() == target) {
        return i;
      }
    }
    return -1;
  }

  /// Returns the userId at [seatIndex], or null if empty.
  String? getUserInSeat(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= seats.length) return null;
    final s = seats[seatIndex];
    if (s == null || s.trim().isEmpty) return null;
    return s;
  }

  /// Returns a flat list of pending seat requests.
  List<Map<String, dynamic>> getPendingRequests() {
    return seatRequests.entries.map((entry) {
      return {'userID': entry.key, ...entry.value};
    }).toList();
  }

  /// Returns a flat list of pending seat invitations.
  List<Map<String, dynamic>> getPendingInvitations() {
    return seatInvitations.entries.map((entry) {
      return {'userID': entry.key, ...entry.value};
    }).toList();
  }

  // ── Seat state update (server-authoritative) ───────────────────────────────

  /// Applies the server-authoritative seat_state payload.
  /// Called every time a seat_state socket event is received.
  void applySeatState({
    required List<String?> newSeats,
    required Set<int> newLockedSeats,
    int? newMaxSeats,
  }) {
    if (newMaxSeats != null && newMaxSeats != maxSeats) {
      maxSeats = newMaxSeats;
    }

    final parsedSeats = List<String?>.filled(maxSeats, null);
    for (int i = 0; i < newSeats.length && i < maxSeats; i++) {
      final s = newSeats[i];
      if (s != null && s.trim().isNotEmpty && s != 'null') {
        parsedSeats[i] = s.trim();
      }
    }

    seats = parsedSeats;
    lockedSeats = Set<int>.from(newLockedSeats);
    serverSeatStateReceived = true;
    _emit('seat_state_updated', {
      'seats': seats,
      'lockedSeats': lockedSeats.toList(),
    });
  }

  // ── Seat request tracking ──────────────────────────────────────────────────

  void addSeatRequest(String userId, String userName, {int? seatIndex}) {
    seatRequests[userId] = {
      'userName': userName,
      'seatIndex': seatIndex,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _emit('seat_request_added', {'userID': userId});
  }

  void removeSeatRequest(String userId) {
    seatRequests.remove(userId);
    _emit('seat_request_removed', {'userID': userId});
  }

  void clearAllSeatRequests() {
    seatRequests.clear();
    _emit('seat_requests_cleared', {});
  }

  // ── Seat invitation tracking ───────────────────────────────────────────────

  void addSeatInvitation(String userId, int seatIndex) {
    seatInvitations[userId] = {
      'seatIndex': seatIndex,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _emit('seat_invitation_added', {'userID': userId, 'seatIndex': seatIndex});
  }

  void removeSeatInvitation(String userId) {
    seatInvitations.remove(userId);
    _emit('seat_invitation_removed', {'userID': userId});
  }

  // ── Own pending request ────────────────────────────────────────────────────

  void setPendingOwnRequest({int? seatIndex}) {
    pendingOwnRequest = {
      'seatIndex': seatIndex,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void clearPendingOwnRequest() {
    pendingOwnRequest = null;
  }

  // ── Reset / cleanup ────────────────────────────────────────────────────────

  void reset() {
    seats = List.filled(maxSeats, null);
    lockedSeats.clear();
    seatRequests.clear();
    seatInvitations.clear();
    pendingOwnRequest = null;
    serverSeatStateReceived = false;
  }

  void dispose() {
    _eventController.close();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _emit(String event, Map<String, dynamic> data) {
    if (!_eventController.isClosed) {
      _eventController.add({'event': event, ...data});
    }
  }
}
