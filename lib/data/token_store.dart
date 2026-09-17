import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the access/refresh token pair across app restarts. Same
/// pattern as king-domain-admin's tokenStore.ts (localStorage there,
/// secure storage here since this is a real device, not a browser tab).
class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  final _storage = const FlutterSecureStorage();
  static const _accessKey = 'kd_access_token';
  static const _refreshKey = 'kd_refresh_token';

  String? _cachedAccess;
  String? _cachedRefresh;

  Future<void> setTokens({required String accessToken, String? refreshToken}) async {
    _cachedAccess = accessToken;
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null) {
      _cachedRefresh = refreshToken;
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    return _cachedAccess ??= await _storage
        .read(key: _accessKey)
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
  }

  Future<String?> getRefreshToken() async {
    return _cachedRefresh ??= await _storage.read(key: _refreshKey);
  }

  Future<void> clear() async {
    _cachedAccess = null;
    _cachedRefresh = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
