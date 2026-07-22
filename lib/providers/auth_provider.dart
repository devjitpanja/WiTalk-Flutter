import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/graphql_service.dart';

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
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AuthNotifier() : super(const AuthState()) {
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    final token = await _storage.read(key: 'accessToken');

    if (uid != null && token != null) {
      state = state.copyWith(status: AuthStatus.authenticated, uid: uid);
    } else if (uid != null) {
      // Try generating fresh tokens for the logged-in user if token is missing
      final refreshed = await graphQLService.refreshToken();
      if (refreshed) {
        state = state.copyWith(status: AuthStatus.authenticated, uid: uid);
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } else {
      await prefs.clear();
      await _storage.deleteAll();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signIn({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', uid);
    await _storage.write(key: 'uid', value: uid);
    final refreshed = await graphQLService.refreshToken();
    state = state.copyWith(
      status: AuthStatus.authenticated,
      uid: uid,
    );
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _storage.deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);
  void setError(String? error) => state = state.copyWith(error: error, isLoading: false);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
