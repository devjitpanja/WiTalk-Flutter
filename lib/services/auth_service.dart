import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/dio_client.dart';
import '../config/app_config.dart';
import '../utils/storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

const _webClientId = AppConfig.googleWebClientId;

class AuthResult {
  final bool success;
  final String? uid;
  final String? nextRoute;
  final String? error;

  const AuthResult({
    required this.success,
    this.uid,
    this.nextRoute,
    this.error,
  });
}

class AuthService {
  static final _googleSignIn = GoogleSignIn(serverClientId: _webClientId);
  static final _firebaseAuth = FirebaseAuth.instance;

  static Future<AuthResult> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return const AuthResult(success: false, error: 'cancelled');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user!;

      final deviceData = await _getDeviceInfo();
      final userPayload = {
        'id': user.uid,
        'name': user.displayName ?? user.email?.split('@').first ?? '',
        'email': user.email,
        'profile_pic': user.photoURL,
        'deviceInfo': deviceData,
      };

      final res = await dioClient.post('/v1/user/create', data: userPayload);

      if (res.data['success'] == true || res.data['exists'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', user.uid);

        // generate-tokens requires Firebase ID token as Bearer header
        final firebaseIdToken = await user.getIdToken();
        final tokenRes = await Dio().post(
          '${AppConfig.apiBaseUrl}/v1/auth/generate-tokens',
          data: {'userId': user.uid},
          options: Options(headers: {
            'Content-Type': 'application/json',
            'x-firebase-token': firebaseIdToken,
          }),
        );
        final tokens = tokenRes.data['data'];
        if (tokens != null) {
          final accessToken = tokens['accessToken'] as String;
          final refreshToken = tokens['refreshToken'] as String;
          final expiresIn = (tokens['expiresIn'] as int?) ?? 900;
          final refreshExpiresIn = (tokens['refreshExpiresIn'] as int?) ?? (30 * 24 * 60 * 60);

          await AppStorage.setAuthTokens(
            accessToken,
            refreshToken,
            expiresIn: expiresIn,
            refreshExpiresIn: refreshExpiresIn,
          );
          await AppStorage.set('uid', user.uid);
          clearTokenCache();
          markTokensAsReady();
        }

        // Check onboarding state
        final statusRes = await dioClient.get('/v1/user/${user.uid}/login-status');
        final data = statusRes.data['data'];
        final profile = data['profile'];
        final onboarding = data['onboarding'];
        final ban = data['ban'];

        if (ban['isBanned'] == true) {
          await _clearAuth();
          return AuthResult(success: false, error: 'banned:${ban['banReason']}');
        }

        final isProfileComplete = profile['name'] != null &&
            profile['profile_pic'] != null &&
            profile['gender'] != null &&
            profile['city'] != null &&
            profile['birthday'] != null;

        String nextRoute;
        if (!isProfileComplete) {
          nextRoute = '/complete-profile';
        } else if (onboarding['isCompleted'] != true) {
          nextRoute = '/purpose-interests';
        } else {
          nextRoute = '/home';
        }

        return AuthResult(
          success: true,
          uid: user.uid,
          nextRoute: nextRoute,
        );
      }

      return const AuthResult(success: false, error: 'Server error');
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  static Future<void> _clearAuth() async {
    await _firebaseAuth.signOut();
    await AppStorage.clear();
    clearTokenCache();
    resetTokenGate();
  }

  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    final info = DeviceInfoPlugin();
    final pkg = await PackageInfo.fromPlatform();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return {
        'brand': android.brand,
        'model': android.model,
        'osVersion': android.version.release,
        'appVersion': pkg.version,
        'platform': 'android',
      };
    } else {
      final ios = await info.iosInfo;
      return {
        'brand': 'Apple',
        'model': ios.model,
        'osVersion': ios.systemVersion,
        'appVersion': pkg.version,
        'platform': 'ios',
      };
    }
  }
}
