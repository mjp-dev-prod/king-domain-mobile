import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';

/// Change for a real device pointed at a deployed backend. 10.0.2.2 is the
/// Android emulator's alias for the host machine's localhost — a physical
/// device needs the host's real LAN IP or a deployed URL instead.
const _apiBase = String.fromEnvironment(
  'KD_API_BASE',
  defaultValue: 'http://10.0.2.2:4000',
);

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);

  @override
  String toString() => message;
}

/// Talks to king-domain-backend's /users and /jobs routes. Access tokens
/// are short-lived (15 min, see backend/src/user/jwt.js) — a 401 on
/// anything other than the auth endpoints themselves triggers a silent
/// refresh-and-retry, same shape as king-domain-admin's api.ts, with
/// concurrent requests sharing one in-flight refresh so a burst of 401s
/// doesn't fire the refresh endpoint multiple times at once.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<String>? _refreshing;

  Future<String> _refreshAccessToken() async {
    final refreshToken = await TokenStore.instance.getRefreshToken();
    if (refreshToken == null) throw ApiException('Not signed in.', 401);

    final response = await http.post(
      Uri.parse('$_apiBase/users/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode != 200) {
      await TokenStore.instance.clear();
      throw ApiException('Session expired. Please sign in again.', 401);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String;
    await TokenStore.instance.setTokens(accessToken: accessToken);
    return accessToken;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool multipart = false,
    List<int>? fileBytes,
    String? fileField,
    String? fileName,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$_apiBase$path');
    final accessToken = await TokenStore.instance.getAccessToken();
    final isAuthEndpoint = path.startsWith('/users/signup') ||
        path.startsWith('/users/login') ||
        path.startsWith('/users/auth/');

    http.Response response;

    try {
      if (multipart && fileBytes != null) {
        final request = http.MultipartRequest(method, uri);
        if (accessToken != null) {
          request.headers['Authorization'] = 'Bearer $accessToken';
        }
        body?.forEach((key, value) => request.fields[key] = value.toString());
        request.files.add(
          http.MultipartFile.fromBytes(
            fileField ?? 'file',
            fileBytes,
            filename: fileName ?? 'upload',
          ),
        );
        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      } else {
        final headers = <String, String>{
          if (body != null) 'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        };
        final encoded = body != null ? jsonEncode(body) : null;

        switch (method) {
          case 'GET':
            response = await http.get(uri, headers: headers);
          case 'POST':
            response = await http.post(uri, headers: headers, body: encoded);
          case 'PATCH':
            response = await http.patch(uri, headers: headers, body: encoded);
          case 'DELETE':
            response = await http.delete(uri, headers: headers);
          default:
            throw ApiException('Unsupported method $method', 0);
        }
      }
    } on http.ClientException {
      throw ApiException('Could not reach the server.', 0);
    }

    if (response.statusCode == 401 && !isRetry && !isAuthEndpoint) {
      try {
        _refreshing ??= _refreshAccessToken().whenComplete(() => _refreshing = null);
        await _refreshing;
        return _request(
          method,
          path,
          body: body,
          multipart: multipart,
          fileBytes: fileBytes,
          fileField: fileField,
          fileName: fileName,
          isRetry: true,
        );
      } catch (_) {
        // Fall through to normal error handling below with the original 401.
      }
    }

    if (response.statusCode == 204) return null;

    Map<String, dynamic>? data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        (data?['error'] as String?) ?? 'Something went wrong.',
        response.statusCode,
      );
    }

    return data;
  }

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, body: body);
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, dynamic> fields,
    List<int>? fileBytes,
    String? fileField,
    String? fileName,
  }) =>
      _request(
        'POST',
        path,
        body: fields,
        multipart: true,
        fileBytes: fileBytes,
        fileField: fileField,
        fileName: fileName,
      );
}
