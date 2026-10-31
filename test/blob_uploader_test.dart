import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/presentation/providers/skill_submissions_provider.dart';

/// The upload goes to a presigned storage link, not to our server: it must carry exactly the headers the link
/// was signed with, send the bytes as given, and never carry our sign-in token.
void main() {
  late HttpServer server;
  late String base;
  final seen = <Map<String, Object?>>[];
  var status = 200;

  setUpAll(() async {
    HttpOverrides.global = null; // flutter_test answers every request 400 unless this is cleared
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      final body = await req.fold<List<int>>([], (a, b) => a..addAll(b));
      seen.add({'method': req.method, 'path': req.uri.toString(), 'type': req.headers.contentType?.mimeType, 'auth': req.headers.value('authorization'), 'bytes': body.length, 'length': req.contentLength});
      req.response.statusCode = status;
      await req.response.close();
    });
  });
  tearDownAll(() => server.close(force: true));
  setUp(() {
    seen.clear();
    status = 200;
  });

  test('PUTs the bytes with the signed content type, a length, no token, and reports progress to 100%', () async {
    final progress = <double>[];
    Stream<List<int>> data() async* {
      yield List.filled(1000, 1);
      yield List.filled(1000, 2);
    }

    await const HttpBlobUploader().put('$base/bucket/key?X-Amz-Signature=abc', {'Content-Type': 'video/mp4'}, data(), 2000, onProgress: progress.add);

    expect(seen, hasLength(1));
    expect(seen.single['method'], 'PUT');
    expect(seen.single['path'], '/bucket/key?X-Amz-Signature=abc');
    expect(seen.single['type'], 'video/mp4');
    expect(seen.single['bytes'], 2000);
    expect(seen.single['length'], 2000);
    expect(seen.single['auth'], isNull);
    expect(progress.last, 1.0);
  });

  test('a refusal from storage is an error the person can read, not a silent success', () async {
    status = 403;
    await expectLater(
      const HttpBlobUploader().put('$base/bucket/key', {'Content-Type': 'video/mp4'}, Stream.value([1, 2, 3]), 3),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('refused (403)'))),
    );
  });

  test('an unreachable host says the upload was interrupted', () async {
    await expectLater(
      const HttpBlobUploader().put('http://127.0.0.1:1/x', {}, Stream.value([1]), 1),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('interrupted'))),
    );
  });
}
