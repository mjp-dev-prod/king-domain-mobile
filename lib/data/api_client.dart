import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show appFlavor;
import 'package:http/http.dart' as http;
import 'token_store.dart';

/// Each app flavor talks to its own backend: the production app to
/// production, the staging app (--flavor staging) to hosted staging. Override
/// with --dart-define=KD_API_BASE=... only for local development, e.g.
/// http://10.0.2.2:4000 for the Android emulator, or the PC's LAN IP for a
/// phone on the same network as a locally-running backend.
const _productionApiBase = 'https://king-domain-backend-1.onrender.com';
const _stagingApiBase = 'https://king-domain-backend-staging.onrender.com';

const _flavorApiBase = appFlavor == 'staging' ? _stagingApiBase : _productionApiBase;
const _apiBase = String.fromEnvironment('KD_API_BASE', defaultValue: _flavorApiBase);

/// host:port of the server the app is talking to when it is NOT production
/// (a --dart-define=KD_API_BASE override), else null. Drives the on-screen
/// test-server banner so a staging run can't be mistaken for production.
final String? nonProductionApiHost = _apiBase == _productionApiBase ? null : _hostAndPort(_apiBase);

String _hostAndPort(String url) {
  final uri = Uri.parse(url);
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}

class ApiException implements Exception {
  final String message;
  final int status;
  /// A stable machine-readable reason when the server sends one ('terms_changed'),
  /// so the app can react without matching message text.
  final String? code;
  /// The rest of the server's answer, for refusals that carry more than a message (the jobs that
  /// block an account deletion).
  final Map<String, dynamic>? data;
  ApiException(this.message, this.status, {this.code, this.data});

  /// Builds the exception for a non-2xx response: the server's `error` text and
  /// optional `code`, or a plain message when the body isn't JSON.
  factory ApiException.fromResponse(int status, String body) {
    Map<String, dynamic>? data;
    try {
      data = body.isEmpty ? null : jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }
    return ApiException((data?['error'] as String?) ?? 'Something went wrong.', status, code: data?['code'] as String?, data: data);
  }

  @override
  String toString() => message;
}

/// The http package has no built-in request timeout — an unreachable host
/// (server down, wrong IP, device off the LAN) hangs the Future forever
/// rather than throwing, which left callers (and their loading spinners)
/// stuck indefinitely instead of surfacing "Could not reach the server."
const _requestTimeout = Duration(seconds: 12);

/// Talks to king-domain-backend's /users and /jobs routes. Access tokens
/// are short-lived (15 min, see backend/src/user/jwt.js) — a 401 on
/// anything other than the auth endpoints themselves triggers a silent
/// refresh-and-retry, same shape as king-domain-admin's api.ts, with
/// concurrent requests sharing one in-flight refresh so a burst of 401s
/// doesn't fire the refresh endpoint multiple times at once.
/// One file of a multi-file upload: the form field it goes in, its bytes and its name.
class UploadPart {
  final String field;
  final List<int> bytes;
  final String name;
  const UploadPart({required this.field, required this.bytes, required this.name});
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<String>? _refreshing;

  Future<String> _refreshAccessToken() async {
    final refreshToken = await TokenStore.instance.getRefreshToken();
    if (refreshToken == null) throw ApiException('Not signed in.', 401);

    final response = await http
        .post(
          Uri.parse('$_apiBase/users/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(_requestTimeout);

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
    List<UploadPart>? parts,
    Duration? timeout,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$_apiBase$path');
    final accessToken = await TokenStore.instance.getAccessToken();
    final isAuthEndpoint = path.startsWith('/users/signup') ||
        path.startsWith('/users/login') ||
        path.startsWith('/users/auth/');

    http.Response response;

    try {
      if (multipart && (fileBytes != null || parts != null)) {
        final request = http.MultipartRequest(method, uri);
        if (accessToken != null) {
          request.headers['Authorization'] = 'Bearer $accessToken';
        }
        body?.forEach((key, value) => request.fields[key] = value.toString());
        if (fileBytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              fileField ?? 'file',
              fileBytes,
              filename: fileName ?? 'upload',
            ),
          );
        }
        // Built fresh on every attempt: a MultipartFile can only be sent once, and a 401 retries.
        for (final p in parts ?? const <UploadPart>[]) {
          request.files.add(http.MultipartFile.fromBytes(p.field, p.bytes, filename: p.name));
        }
        final streamed = await request.send().timeout(timeout ?? _requestTimeout);
        response = await http.Response.fromStream(streamed);
      } else {
        final headers = <String, String>{
          if (body != null) 'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        };
        final encoded = body != null ? jsonEncode(body) : null;

        switch (method) {
          case 'GET':
            response = await http.get(uri, headers: headers).timeout(_requestTimeout);
          case 'POST':
            response = await http
                .post(uri, headers: headers, body: encoded)
                .timeout(_requestTimeout);
          case 'PATCH':
            response = await http
                .patch(uri, headers: headers, body: encoded)
                .timeout(_requestTimeout);
          case 'PUT':
            response = await http
                .put(uri, headers: headers, body: encoded)
                .timeout(_requestTimeout);
          case 'DELETE':
            response = await http.delete(uri, headers: headers, body: encoded).timeout(_requestTimeout);
          default:
            throw ApiException('Unsupported method $method', 0);
        }
      }
    } on TimeoutException {
      throw ApiException('Could not reach the server.', 0);
    } on http.ClientException {
      throw ApiException('Could not reach the server.', 0);
    }

    if (response.statusCode == 401 && !isRetry && !isAuthEndpoint) {
      try {
        _refreshing ??= _refreshAccessToken().whenComplete(() => _refreshing = null);
        await _refreshing;
        return await _request(
          method,
          path,
          body: body,
          multipart: multipart,
          fileBytes: fileBytes,
          fileField: fileField,
          fileName: fileName,
          parts: parts,
          timeout: timeout,
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
      throw ApiException.fromResponse(response.statusCode, response.body);
    }

    return data;
  }

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, body: body);
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, body: body);
  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _request('PUT', path, body: body);
  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) =>
      _request('DELETE', path, body: body);

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

  /// Several files in one request (an identity document and a selfie video). Videos are big and
  /// phones are slow, so the caller can allow far longer than a normal request.
  Future<dynamic> postMultipartParts(
    String path, {
    required Map<String, dynamic> fields,
    required List<UploadPart> parts,
    Duration timeout = const Duration(minutes: 3),
  }) =>
      _request('POST', path, body: fields, multipart: true, parts: parts, timeout: timeout);

  /// One file, sent with PUT (a profile photo replaces whatever was there). The file goes in the
  /// field the server reads, "file".
  Future<dynamic> putMultipart(
    String path, {
    required List<int> fileBytes,
    String? fileName,
  }) =>
      _request('PUT', path, multipart: true, fileBytes: fileBytes, fileField: 'file', fileName: fileName);
}
