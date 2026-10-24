import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/presentation/providers/push_gateway.dart';
import 'package:king_domain/presentation/providers/push_service.dart';

import 'push_fakes.dart';

/// PushService decides when this phone is registered for pushes. The rules that matter:
/// it never asks Android for permission by accident, registers only when allowed, follows a rotated
/// token, and on logout takes the phone off the account so the next person never gets these pushes.
void main() {
  late FakeGateway gateway;
  late FakeServer server;
  late PushService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    gateway = FakeGateway();
    server = FakeServer();
    service = PushService(gateway: gateway, server: server);
  });

  group('registering', () {
    test('sends the token to the server when notifications are allowed', () async {
      gateway.permissionNow = PushPermission.granted;
      gateway.tokenValue = 'tok-1';
      await service.registerIfAllowed();
      expect(server.registered, ['tok-1']);
    });

    test('does nothing, and never reads the token, unless allowed (reading it can show the permission prompt)', () async {
      for (final p in [PushPermission.notAsked, PushPermission.denied, PushPermission.unavailable]) {
        gateway.permissionNow = p;
        gateway.tokenValue = 'tok-1';
        await service.registerIfAllowed();
      }
      expect(server.registered, isEmpty);
      expect(gateway.tokenReads, 0);
    });

    test('follows a rotated token, and calling it again does not double the listener', () async {
      gateway.permissionNow = PushPermission.granted;
      gateway.tokenValue = 'tok-1';
      await service.registerIfAllowed();
      await service.registerIfAllowed();
      server.registered.clear();
      gateway.refresh.add('tok-2');
      await pumpEventQueue();
      expect(server.registered, ['tok-2'], reason: 'one new registration, not two');
    });

    test('a server that is down never breaks the app', () async {
      gateway.permissionNow = PushPermission.granted;
      gateway.tokenValue = 'tok-1';
      server.failing = true;
      await service.registerIfAllowed(); // must not throw
      expect(server.registered, isEmpty);
    });

    test('no token yet (Firebase not ready) registers nothing', () async {
      gateway.permissionNow = PushPermission.granted;
      gateway.tokenValue = null;
      await service.registerIfAllowed();
      expect(server.registered, isEmpty);
    });
  });

  group('asking', () {
    test('turning on asks Android, and registers when it says yes', () async {
      gateway.permissionNow = PushPermission.notAsked;
      gateway.grantsOnRequest = PushPermission.granted;
      gateway.tokenValue = 'tok-1';
      final result = await service.enable();
      expect(result, PushPermission.granted);
      expect(gateway.requests, 1);
      expect(server.registered, ['tok-1']);
    });

    test('a refusal registers nothing', () async {
      gateway.permissionNow = PushPermission.notAsked;
      gateway.grantsOnRequest = PushPermission.denied;
      gateway.tokenValue = 'tok-1';
      expect(await service.enable(), PushPermission.denied);
      expect(server.registered, isEmpty);
    });

    test('the explanation is offered once: only while not asked, and never again after an answer or "Not now"', () async {
      gateway.permissionNow = PushPermission.notAsked;
      expect(await service.shouldPrompt(), isTrue);
      await service.declinePrompt();
      expect(await service.shouldPrompt(), isFalse);

      // The answer is remembered across restarts (the secure store), not just in memory.
      final again = PushService(gateway: gateway, server: server);
      expect(await again.shouldPrompt(), isFalse);
    });

    test('and never when it would not help', () async {
      for (final p in [PushPermission.granted, PushPermission.denied, PushPermission.unavailable]) {
        gateway.permissionNow = p;
        expect(await service.shouldPrompt(), isFalse, reason: p.name);
      }
    });

    test('enabling counts as having been asked', () async {
      gateway.permissionNow = PushPermission.notAsked;
      gateway.grantsOnRequest = PushPermission.denied;
      await service.enable();
      gateway.permissionNow = PushPermission.notAsked; // e.g. the phone forgot
      expect(await service.shouldPrompt(), isFalse);
    });
  });

  group('logging out', () {
    test('takes this phone off the account on the server, then drops the token from Firebase', () async {
      gateway.permissionNow = PushPermission.granted;
      gateway.tokenValue = 'tok-1';
      await service.registerIfAllowed();
      await service.unregister();
      expect(server.removed, ['tok-1']);
      expect(gateway.deleted, isTrue);
      expect(gateway.order, containsAllInOrder(['token', 'deleteToken']));
      server.registered.clear();
      gateway.refresh.add('tok-9');
      await pumpEventQueue();
      expect(server.registered, isEmpty, reason: 'it stopped following the token');
    });

    test('a person who never allowed pushes is not asked anything and nothing is sent', () async {
      gateway.permissionNow = PushPermission.notAsked;
      await service.unregister();
      expect(gateway.tokenReads, 0);
      expect(server.removed, isEmpty);
      expect(gateway.deleted, isFalse);
    });

    test('the Firebase token is dropped even when the server cannot be reached', () async {
      gateway.permissionNow = PushPermission.granted;
      gateway.tokenValue = 'tok-1';
      server.failing = true;
      await service.unregister(); // must not throw
      expect(gateway.deleted, isTrue);
    });
  });
}
