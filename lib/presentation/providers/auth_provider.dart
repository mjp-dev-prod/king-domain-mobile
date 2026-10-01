import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../data/token_store.dart';

/// Mirrors king-domain-backend's publicUser() shape (src/user/routes.js).
class AuthUser {
  final String id;
  final String email;
  final String role; // 'talent' | 'client'
  final String fullName;
  final bool emailVerified;

  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    required this.emailVerified,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      fullName: json['fullName'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }
}

class AuthState {
  final AuthUser? user;
  final bool loading;

  const AuthState({this.user, this.loading = true});

  AuthState copyWith({AuthUser? user, bool? loading, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
    );
  }
}

/// Real auth, replacing the previous "any valid-looking input proceeds"
/// mock in login_screen.dart/sign_up_screen.dart. Talks to
/// king-domain-backend's /users routes (Sprint 1) directly — see
/// docs/research/BACKEND_SPRINT_PLAN.md.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthState(loading: true);
  }

  Future<void> _restoreSession() async {
    try {
      final token = await TokenStore.instance.getAccessToken();
      if (token == null) {
        state = const AuthState(loading: false);
        return;
      }
      final data = await ApiClient.instance.get('/users/me');
      state = AuthState(user: AuthUser.fromJson(data['user'] as Map<String, dynamic>), loading: false);
    } catch (_) {
      // Covers both an expired/invalid token (no way to refresh) and secure
      // storage being unavailable (e.g. no platform channel, as in widget
      // tests) — either way, fail into "not signed in" rather than hanging.
      try {
        await TokenStore.instance.clear();
      } catch (_) {
        // Storage itself may be what's unavailable — nothing to clean up.
      }
      state = const AuthState(loading: false);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    required String fullName,
  }) async {
    final data = await ApiClient.instance.post(
      '/users/signup',
      body: {'email': email, 'password': password, 'role': role, 'fullName': fullName},
    );
    await TokenStore.instance.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    state = AuthState(user: AuthUser.fromJson(data['user'] as Map<String, dynamic>), loading: false);
  }

  Future<void> login({required String email, required String password}) async {
    final data = await ApiClient.instance.post(
      '/users/login',
      body: {'email': email, 'password': password},
    );
    await TokenStore.instance.setTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    state = AuthState(user: AuthUser.fromJson(data['user'] as Map<String, dynamic>), loading: false);
  }

  Future<void> verifyEmail(String code) async {
    final data = await ApiClient.instance.post('/users/verify-email', body: {'code': code});
    state = state.copyWith(user: AuthUser.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> resendCode() => ApiClient.instance.post('/users/resend-code');

  /// The server replies the same way whether or not an account exists for
  /// [email], so success here never confirms that one does.
  Future<void> requestPasswordReset(String email) =>
      ApiClient.instance.post('/users/auth/forgot-password', body: {'email': email});

  /// Signs the account out everywhere server-side; the user then signs in
  /// with the new password — no automatic login.
  Future<void> resetPassword({required String email, required String code, required String newPassword}) =>
      ApiClient.instance.post(
        '/users/auth/reset-password',
        body: {'email': email, 'code': code, 'newPassword': newPassword},
      );

  Future<void> logout() async {
    final refreshToken = await TokenStore.instance.getRefreshToken();
    try {
      await ApiClient.instance.post('/users/auth/logout', body: {'refreshToken': refreshToken});
    } catch (_) {
      // Logging out locally still matters even if the network call fails.
    }
    await TokenStore.instance.clear();
    state = const AuthState(loading: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
