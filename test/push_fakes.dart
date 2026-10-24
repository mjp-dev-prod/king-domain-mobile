import 'dart:async';

import 'package:king_domain/presentation/providers/push_gateway.dart';
import 'package:king_domain/presentation/providers/push_service.dart';

/// A phone's Firebase, as the tests need it: what permission says, the token, and the three kinds of
/// message (arrived while the app is open, tapped while it was in the background, tapped to start it).
class FakeGateway implements PushGateway {
  PushPermission permissionNow = PushPermission.granted;
  PushPermission grantsOnRequest = PushPermission.granted;
  String? tokenValue = 'tok-fake';
  PushMessage? launch;
  int requests = 0;
  int tokenReads = 0;
  bool deleted = false;
  final order = <String>[];

  final refresh = StreamController<String>.broadcast();
  final foregroundMessages = StreamController<PushMessage>.broadcast();
  final openedMessages = StreamController<PushMessage>.broadcast();

  @override
  Future<PushPermission> permission() async => permissionNow;

  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    permissionNow = grantsOnRequest;
    return grantsOnRequest;
  }

  @override
  Future<String?> token() async {
    tokenReads++;
    order.add('token');
    return tokenValue;
  }

  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get foreground => foregroundMessages.stream;
  @override
  Stream<PushMessage> get opened => openedMessages.stream;
  @override
  Future<PushMessage?> launchMessage() async => launch;

  @override
  Future<void> deleteToken() async {
    order.add('deleteToken');
    deleted = true;
  }
}

/// The backend's two device routes, recorded.
class FakeServer implements PushServer {
  final registered = <String>[];
  final removed = <String>[];
  bool failing = false;

  @override
  Future<void> register(String token) async {
    if (failing) throw Exception('server down');
    registered.add(token);
  }

  @override
  Future<void> unregister(String token) async {
    if (failing) throw Exception('server down');
    removed.add(token);
  }
}
