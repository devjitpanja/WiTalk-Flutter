import 'dart:convert';
import 'logger.dart';

class CallLogger {
  late String _sessionId;
  late int _startTime;
  final List<Map<String, dynamic>> _logs = [];
  final Map<String, int> _eventCounts = {};

  CallLogger() {
    _reset();
  }

  void _reset() {
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _sessionId = 'call-$_startTime';
    _logs.clear();
    _eventCounts.clear();
  }

  String _timestamp() {
    final elapsed = (DateTime.now().millisecondsSinceEpoch - _startTime) / 1000.0;
    return '[+${elapsed.toStringAsFixed(3)}s]';
  }

  void log(String category, String event, [Map<String, dynamic>? data]) {
    final ts = _timestamp();
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'elapsed': ts,
      'category': category,
      'event': event,
      'data': data ?? {},
      'sessionId': _sessionId,
    };
    _logs.add(entry);
    final key = '$category:$event';
    _eventCounts[key] = (_eventCounts[key] ?? 0) + 1;
    AppLogger.log('$ts [$category] $event', data);
  }

  // WebRTC Connection State
  void iceConnectionState(String state, [Map<String, dynamic>? details]) =>
      log('ICE_CONNECTION', state.toUpperCase(), details);

  void connectionState(String state, [Map<String, dynamic>? details]) =>
      log('PEER_CONNECTION', state.toUpperCase(), details);

  void iceGatheringState(String state, [Map<String, dynamic>? details]) =>
      log('ICE_GATHERING', state.toUpperCase(), details);

  void signalingState(String state, [Map<String, dynamic>? details]) =>
      log('SIGNALING', state.toUpperCase(), details);

  // Socket
  void socketConnect(String socketId) => log('SOCKET', 'CONNECTED', {'socketId': socketId});
  void socketDisconnect(String reason) => log('SOCKET', 'DISCONNECTED', {'reason': reason});
  void socketEmit(String event, [Map<String, dynamic>? data]) => log('SOCKET_EMIT', event, data);
  void socketReceive(String event, [Map<String, dynamic>? data]) => log('SOCKET_RECEIVE', event, data);

  // SDP
  void offerCreated(String? sdp) => log('SDP', 'OFFER_CREATED', {'type': 'offer', 'sdpLength': sdp?.length});
  void offerSent() => log('SDP', 'OFFER_SENT');
  void offerReceived(String? sdp) => log('SDP', 'OFFER_RECEIVED', {'type': 'offer', 'sdpLength': sdp?.length});
  void answerCreated(String? sdp) => log('SDP', 'ANSWER_CREATED', {'type': 'answer', 'sdpLength': sdp?.length});
  void answerSent() => log('SDP', 'ANSWER_SENT');
  void answerReceived(String? sdp) => log('SDP', 'ANSWER_RECEIVED', {'type': 'answer', 'sdpLength': sdp?.length});

  void iceCandidateSent(Map<String, dynamic>? candidate) =>
      log('ICE_CANDIDATE', 'SENT', {
        'candidate': (candidate?['candidate'] as String?)?.substring(0, 50),
        'type': candidate?['type'],
      });

  void iceCandidateReceived(Map<String, dynamic>? candidate) =>
      log('ICE_CANDIDATE', 'RECEIVED', {
        'candidate': (candidate?['candidate'] as String?)?.substring(0, 50),
        'type': candidate?['type'],
      });

  // Media
  void localStreamAcquired(int trackCount) => log('MEDIA', 'LOCAL_STREAM_ACQUIRED', {'trackCount': trackCount});
  void remoteStreamReceived(int trackCount) => log('MEDIA', 'REMOTE_STREAM_RECEIVED', {'trackCount': trackCount});
  void remoteTrackAdded(String trackKind) => log('MEDIA', 'REMOTE_TRACK_ADDED', {'trackKind': trackKind});
  void audioFlowing(bool isFlowing) => log('MEDIA', 'AUDIO_FLOWING', {'isFlowing': isFlowing});

  // UI State
  void uiStateChange(String stateName, dynamic value) =>
      log('UI_STATE', stateName.toUpperCase(), {'value': value});
  void statusChange(String oldStatus, String newStatus) =>
      log('UI_STATUS', 'CHANGED', {'from': oldStatus, 'to': newStatus});
  void callTimerStarted() =>
      log('CALL_TIMER', 'STARTED', {'time': DateTime.now().toIso8601String()});

  // Room
  void roomJoined(String roomId, dynamic participants) =>
      log('ROOM', 'JOINED', {'roomId': roomId, 'participants': participants});
  void roomInfo(String roomId, Map<String, dynamic> data) =>
      log('ROOM', 'INFO_RECEIVED', {'roomId': roomId, ...data});
  void peerJoined(String partnerId) => log('ROOM', 'PEER_JOINED', {'partnerId': partnerId});
  void peerLeft(String reason) => log('ROOM', 'PEER_LEFT', {'reason': reason});

  // Errors
  void error(String category, String message, [Map<String, dynamic>? details]) =>
      log('ERROR', '${category}_ERROR', {'message': message, ...?details});

  Map<String, dynamic> getSummary() => {
    'sessionId': _sessionId,
    'duration': DateTime.now().millisecondsSinceEpoch - _startTime,
    'totalEvents': _logs.length,
    'eventCounts': _eventCounts,
    'logs': _logs,
  };

  String exportLogs() => const JsonEncoder.withIndent('  ').convert(getSummary());

  void reset() => _reset();
}

final callLogger = CallLogger();
