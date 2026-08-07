import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'logger.dart';

const _channel = MethodChannel('com.witalk/app_integrity');

/// Result of an integrity check.
class IntegrityResult {
  final bool success;
  final String token;
  final String nonce;
  final String keyId;    // iOS App Attest key ID (empty on Android / DeviceCheck)
  final String method;   // "play_integrity" | "app_attest" | "device_check" | "unavailable"
  final String? error;

  const IntegrityResult({
    required this.success,
    this.token = '',
    this.nonce = '',
    this.keyId = '',
    this.method = 'unavailable',
    this.error,
  });
}

/// Request an integrity token.
///
/// Android : Google Play Integrity API token + nonce.
/// iOS 14+ : DCAppAttestService attestation (Base64 CBOR attestation object) + key ID.
/// iOS 11-13: DeviceCheck token.
/// iOS <11 : Returns IntegrityResult(success: false, method: 'unavailable').
///
/// Always soft-fails — never throws. The RN implementation also soft-fails on all
/// platforms so that a missing Play Services or un-enrolled device doesn't block signup.
Future<IntegrityResult> requestIntegrityToken({String? userId}) async {
  final nonce = _generateNonce(userId: userId);
  try {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'requestIntegrityToken',
      {'nonce': nonce},
    );

    if (result == null) {
      return IntegrityResult(success: false, nonce: nonce, method: 'unavailable', error: 'Null response');
    }

    if (result.containsKey('error')) {
      AppLogger.warn('[AppIntegrity] Error: ${result['error']}');
      return IntegrityResult(success: false, nonce: nonce, method: 'unavailable', error: result['error'] as String);
    }

    final method = Platform.isIOS
        ? (result['method'] as String? ?? 'app_attest')
        : 'play_integrity';

    return IntegrityResult(
      success: true,
      token: result['token'] as String? ?? '',
      nonce: result['nonce'] as String? ?? nonce,
      keyId: result['keyId'] as String? ?? '',
      method: method,
    );
  } on MissingPluginException {
    AppLogger.warn('[AppIntegrity] Plugin not available (debug/simulator)');
    return IntegrityResult(success: false, nonce: nonce, method: 'unavailable', error: 'Plugin not available');
  } catch (e) {
    AppLogger.warn('[AppIntegrity] requestIntegrityToken failed: $e');
    return IntegrityResult(success: false, nonce: nonce, method: 'unavailable', error: e.toString());
  }
}

/// Generates a cryptographically random nonce.
/// Incorporates userId and timestamp to ensure uniqueness per request.
String _generateNonce({String? userId}) {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final uid = userId?.substring(0, userId.length.clamp(0, 8)) ?? 'anon';
  return '$uid-$ts-$hex';
}
