import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/account.dart';
import 'package:king_domain/data/token_store.dart';

/// Deleting an account is a DELETE that carries the password in its body, and a refusal for an active
/// contract carries the list of jobs, which the app shows.
void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStore.instance.setTokens(accessToken: 'test-access-token');
  });

  test('delete sends the JSON body and the bearer token', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
    });

    final data = await http.runWithClient(() => ApiClient.instance.delete('/users/me', body: {'password': 'secret'}), () => client);

    expect(seen.method, 'DELETE');
    expect(seen.url.path, '/users/me');
    expect(seen.headers['Authorization'], 'Bearer test-access-token');
    expect(seen.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(seen.body), {'password': 'secret'});
    expect((data as Map)['ok'], true);
  });

  test('delete without a body still sends none (the photo route)', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response('{"user":{}}', 200, headers: {'content-type': 'application/json'});
    });
    await http.runWithClient(() => ApiClient.instance.delete('/users/me/photo'), () => client);
    expect(seen.body, isEmpty);
  });

  test('a wrong password is a 403 with its code, and is not retried as an expired session', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{"error":"That password is incorrect.","code":"wrong_password"}', 403, headers: {'content-type': 'application/json'});
    });

    await expectLater(
      http.runWithClient(() => ApiClient.instance.delete('/users/me', body: {'password': 'x'}), () => client),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 403).having((e) => e.code, 'code', 'wrong_password')),
    );
    expect(calls, 1);
  });

  test('an active-contract refusal keeps the jobs, readable as ActiveContract', () async {
    final client = MockClient((request) async => http.Response(
          '{"error":"You have a job in progress.","code":"active_contracts","contracts":[{"jobId":"j1","title":"Logo and brand kit","role":"client","status":"inProgress"},{"jobId":"j2","title":"Poster","role":"talent","status":"submitted"}]}',
          409,
          headers: {'content-type': 'application/json'},
        ));

    ApiException? caught;
    try {
      await http.runWithClient(() => ApiClient.instance.delete('/users/me', body: {'password': 'x'}), () => client);
    } on ApiException catch (e) {
      caught = e;
    }

    expect(caught, isNotNull);
    expect(caught!.code, 'active_contracts');
    final jobs = ActiveContract.listFrom(caught.data);
    expect(jobs.map((j) => (j.jobId, j.title, j.role, j.status)), [('j1', 'Logo and brand kit', 'client', 'inProgress'), ('j2', 'Poster', 'talent', 'submitted')]);
  });

  test('ActiveContract.listFrom is empty when there is nothing to read', () {
    expect(ActiveContract.listFrom(null), isEmpty);
    expect(ActiveContract.listFrom({'contracts': 'nope'}), isEmpty);
  });
}
