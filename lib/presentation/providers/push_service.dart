import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/api_client.dart';
import 'push_gateway.dart';

/// The backend's two device routes (king-domain-backend `PUT` and `DELETE /users/me/device`).
abstract class PushServer {
  Future<void> register(String token);
  Future<void> unregister(String token);
}

class ApiPushServer implements PushServer {
  const ApiPushServer();

  @override
  Future<void> register(String token) => ApiClient.instance.put('/users/me/device', body: {'token': token});

  @override
  Future<void> unregister(String token) => ApiClient.instance.delete('/users/me/device', body: {'token': token});
}

/// Decides when this phone is registered for pushes (docs/features/push-notifications.md).
///
/// It never asks Android for permission by accident, registers only when allowed, follows a token that
/// Firebase rotates, and on logout takes the phone off the account so the next person on a shared phone
/// never receives the last person's pushes. A server that is down never breaks the app: registering is
/// retried at the next start.
class PushService {
  PushService({required this.gateway, required this.server, FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final PushGateway gateway;
  final PushServer server;
  final FlutterSecureStorage _storage;
  StreamSubscription<String>? _refresh;

  static const _promptedKey = 'push_prompted';

  Future<PushPermission> permission() => gateway.permission();

  Future<void> _send(String token) async {
    try {
      await server.register(token);
    } catch (error) {
      debugPrint('push: could not register this phone yet ($error); will retry at the next start');
    }
  }

  /// Registers this phone when notifications are allowed. Safe to call at every start.
  Future<void> registerIfAllowed() async {
    if (await gateway.permission() != PushPermission.granted) return;
    final token = await gateway.token();
    if (token != null) await _send(token);
    _refresh ??= gateway.tokenRefresh.listen(_send);
  }

  /// The person said yes to the explanation (or tapped the Notifications row): ask Android, and register.
  Future<PushPermission> enable() async {
    final result = await gateway.requestPermission();
    await declinePrompt(); // however they answered, they have been asked
    if (result == PushPermission.granted) await registerIfAllowed();
    return result;
  }

  Future<bool> _prompted() async => await _storage.read(key: _promptedKey) == '1';

  /// Whether to show the one-time explanation: only while Android would still ask, and only once.
  Future<bool> shouldPrompt() async => await gateway.permission() == PushPermission.notAsked && !await _prompted();

  /// "Not now", or any answer: never show the explanation again.
  Future<void> declinePrompt() => _storage.write(key: _promptedKey, value: '1');

  /// Logout: remove this phone from the account on the server, then drop the token from Firebase.
  Future<void> unregister() async {
    await _refresh?.cancel();
    _refresh = null;
    if (await gateway.permission() != PushPermission.granted) return; // nothing was ever registered
    final token = await gateway.token();
    if (token != null) {
      try {
        await server.unregister(token);
      } catch (error) {
        debugPrint('push: could not remove this phone from the server ($error)');
      }
    }
    await gateway.deleteToken();
  }
}

final pushServerProvider = Provider<PushServer>((ref) => const ApiPushServer());

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(gateway: ref.watch(pushGatewayProvider), server: ref.watch(pushServerProvider)),
);

/// The permission as the Notifications row shows it. Refreshed by invalidating it after a change.
final pushPermissionProvider = FutureProvider.autoDispose<PushPermission>((ref) => ref.watch(pushServiceProvider).permission());
