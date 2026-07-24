import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/dio_client.dart';
import 'storage.dart';
import 'logger.dart';

/// Perform a complete logout — signs out from all services and clears all data.
Future<bool> performLogout({bool clearStorage = true}) async {
  try {
    AppLogger.log('[AuthUtils] Starting logout process...');

    // 1. Sign out from Google
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
        await googleSignIn.signOut();
        AppLogger.emoji('✅', 'Google sign out successful');
      }
    } catch (e) {
      AppLogger.log('[AuthUtils] Google sign out skipped: ${e.toString()}');
    }

    // 2. Sign out from Firebase
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
        AppLogger.emoji('✅', 'Firebase sign out successful');
      }
    } catch (e) {
      AppLogger.error('[AuthUtils] Firebase sign out error', e);
    }

    // 3. Disconnect all socket.io connections
    try {
      io.io('', <String, dynamic>{'autoConnect': false}).dispose();
      AppLogger.emoji('✅', 'Socket connections closed');
    } catch (_) {}

    // 4. Clear all local storage & token gate
    clearTokenCache();
    resetTokenGate();
    if (clearStorage) {
      try {
        await AppStorage.clear();
        AppLogger.emoji('✅', 'All local data cleared');
      } catch (e) {
        AppLogger.error('[AuthUtils] Error clearing storage', e);
        // Fallback: clear critical auth data
        try {
          await AppStorage.clearAuthTokens();
          await AppStorage.remove('uid');
          await AppStorage.remove('username');
        } catch (_) {}
      }
    } else {
      await AppStorage.clearAuthTokens();
      await AppStorage.remove('uid');
      await AppStorage.remove('username');
    }

    AppLogger.separator('LOGOUT COMPLETED SUCCESSFULLY');
    return true;
  } catch (e) {
    AppLogger.error('[AuthUtils] Error during logout', e);
    try {
      await AppStorage.clearAuthTokens();
      await AppStorage.remove('uid');
    } catch (_) {}
    return false;
  }
}

/// Check if user session is valid (uid exists + tokens present).
Future<bool> isSessionValid() async {
  try {
    final uid = await AppStorage.get('uid') as String?;
    final hasTokens = await AppStorage.hasAuthTokens();
    return uid != null && uid.isNotEmpty && hasTokens;
  } catch (e) {
    AppLogger.error('[AuthUtils] Error checking session validity', e);
    return false;
  }
}

/// Get current user ID from storage.
Future<String?> getCurrentUserId() async {
  try {
    return await AppStorage.get('uid') as String?;
  } catch (e) {
    AppLogger.error('[AuthUtils] Error getting current user ID', e);
    return null;
  }
}

/// Clear session data if access token expired and no refresh token available.
Future<void> clearExpiredSession() async {
  try {
    final isExpired = await AppStorage.isAccessTokenExpired();
    final refreshToken = await AppStorage.getRefreshToken();
    if (isExpired && (refreshToken == null || refreshToken.isEmpty)) {
      AppLogger.log('[AuthUtils] Clearing expired session (no refresh token)');
      await AppStorage.clearAuthTokens();
      await AppStorage.remove('uid');
    }
  } catch (e) {
    AppLogger.error('[AuthUtils] Error clearing expired session', e);
  }
}
