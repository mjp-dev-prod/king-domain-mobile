import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/token_store.dart';

/// The profile photo is one multipart PUT. The picture goes in the field the server reads ("file"),
/// with a file name, and the sign-in token rides along.
void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStore.instance.setTokens(accessToken: 'test-access-token');
  });

  test('putMultipart sends a PUT with the file in the "file" field and the bearer token', () async {
    late http.BaseRequest seen;
    String? body;
    final client = MockClient.streaming((request, bodyStream) async {
      seen = request;
      body = latin1.decode(await bodyStream.expand((c) => c).toList());
      return http.StreamedResponse(Stream.value(utf8.encode('{"user":{"id":"u1"}}')), 200, headers: {'content-type': 'application/json'});
    });

    final data = await http.runWithClient(
      () => ApiClient.instance.putMultipart('/users/me/photo', fileBytes: [1, 2, 3], fileName: 'me.jpg'),
      () => client,
    );

    expect(seen.method, 'PUT');
    expect(seen.url.path, '/users/me/photo');
    expect(seen.headers['Authorization'], 'Bearer test-access-token');
    expect(seen.headers['content-type'], startsWith('multipart/form-data'));
    expect(body, contains('name="file"'));
    expect(body, contains('filename="me.jpg"'));
    expect((data as Map)['user']['id'], 'u1');
  });

  test('a refusal from the server keeps its message and code', () async {
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"error":"That file is too large. The limit is 5 MB.","code":"file_too_large"}')),
        413,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      http.runWithClient(() => ApiClient.instance.putMultipart('/users/me/photo', fileBytes: [1], fileName: 'big.jpg'), () => client),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 413).having((e) => e.code, 'code', 'file_too_large').having((e) => e.message, 'message', contains('5 MB'))),
    );
  });
}
