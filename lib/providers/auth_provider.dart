import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../utils/storage.dart';
import '../utils/auth_utils.dart';
import '../utils/logger.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? uid;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.uid,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, String? uid, bool? isLoading, String? error}) => AuthState(
        status: status ?? this.status,
        uid: uid ?? this.uid,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription<ForceLogoutEvent>? _forceLogoutSub;

  AuthNotifier() : super(const AuthState()) {
    _listenToForceLogout();
    _checkExistingAuth();
  }

  void _listenToForceLogout() {
    _forceLogoutSub = onForceLogout.listen((event) {
      AppLogger.warn('[AuthNotifier] Force logout received: ${event.reason} - ${event.message}');
      state = state.copyWith(status: AuthStatus.unauthenticated, uid: null, error: event.message);
    });
  }

  Future<void> _checkExistingAuth() async {
    try {
      final uid = await AppStorage.get('uid') as String?;
      final hasTokens = await AppStorage.hasAuthTokens();
      final isExpired = await AppStorage.isAccessTokenExpired();

      if (uid != null && uid.isNotEmpty && hasTokens && !isExpired) {
        AppLogger.emoji('⚡', '[AuthNotifier] Valid tokens found on launch - unblocking API calls immediately');
        markTokensAsReady();
        state = state.copyWith(status: AuthStatus.authenticated, uid: uid);
        return;
      }

      if (uid != null && uid.isNotEmpty) {
        AppLogger.log('[AuthNotifier] Expired or missing tokens on launch - performing background validation...');
        final result = await performTokenRefresh(uid: uid);
        if (result.success || result.isNetworkError) {
          markTokensAsReady();
          state = state.copyWith(status: AuthStatus.authenticated, uid: uid);
        } else {
          markTokensAsReady();
          state = state.copyWith(status: AuthStatus.unauthenticated, uid: null);
        }
      } else {
        markTokensAsReady();
        state = state.copyWith(status: AuthStatus.unauthenticated, uid: null);
      }
    } catch (e) {
      AppLogger.error('[AuthNotifier] Error checking existing auth', e);
      markTokensAsReady();
      state = state.copyWith(status: AuthStatus.unauthenticated, uid: null);
    }
  }

  Future<void> signIn({required String uid}) async {
    await AppStorage.set('uid', uid);
    await performTokenRefresh(uid: uid);
    markTokensAsReady();
    state = state.copyWith(
      status: AuthStatus.authenticated,
      uid: uid,
    );
  }

  Future<void> signOut() async {
    await performLogout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);
  void setError(String? error) => state = state.copyWith(error: error, isLoading: false);

  @override
  void dispose() {
    _forceLogoutSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

