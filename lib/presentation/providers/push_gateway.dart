import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where this phone stands on notifications.
///
/// [notAsked] means Android will still show its prompt: either never asked, or refused once. The plugin
/// cannot tell those apart on Android (firebase_messaging reports both as `denied`), and does not need to:
/// asking again is harmless. [denied] means refused for good, so only the phone's settings can change it.
/// [unavailable] means Firebase is not set up on this build or phone: push is simply off, silently.
enum PushPermission { granted, notAsked, denied, unavailable }

/// A push, as the app needs it: what it says, and which job it is about (`data['jobId']`).
class PushMessage {
  final String title;
  final String body;
  final Map<String, String> data;
  const PushMessage({required this.title, required this.body, this.data = const {}});

  String? get jobId => data['jobId'];

  /// A skill result or step (the server sends type skill_verified, skill_not_yet, skill_checked or skill_needs_change).
  bool get isSkill => (data['type'] ?? '').startsWith('skill_');

  factory PushMessage.fromRemote(RemoteMessage m) => PushMessage(
        title: m.notification?.title ?? '',
        body: m.notification?.body ?? '',
        data: m.data.map((k, v) => MapEntry(k, '$v')),
      );
}

/// The phone's Firebase Messaging, behind a seam so tests do not need Firebase (like the photo picker).
abstract class PushGateway {
  /// The current state, without asking.
  Future<PushPermission> permission();

  /// Shows Android's prompt (Android 13+) and says what the person chose.
  Future<PushPermission> requestPermission();

  /// This install's token, or null. Only ever reads it when notifications are allowed: asking Firebase
  /// for a token can itself pop up the permission prompt.
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// Arrived while the app is open (Android shows nothing itself then).
  Stream<PushMessage> get foreground;

  /// Tapped while the app was in the background.
  Stream<PushMessage> get opened;

  /// Tapped while the app was closed: the push that started it.
  Future<PushMessage?> launchMessage();
  Future<void> deleteToken();
}

/// The real thing. Every method is defensive: a build without google-services.json, a phone without
/// Play services, or a test with no Firebase gives [PushPermission.unavailable] and quiet no-ops, never an
/// exception into the app.
///
/// Registration uses the registration-token APIs (`getToken`, `onTokenRefresh`, `deleteToken`). Firebase
/// marks them deprecated in favour of Installation IDs (`register`, `onRegistered`) but they still work,
/// FCM's send `token` field accepts both during the migration, and the token path is the one proven in
/// production. Moving to Installation IDs is a tracked follow-up (docs/features/push-notifications.md):
/// it needs a manifest opt-in and the `fid` field on the server, and cannot be checked without a device.
class FirebasePushGateway implements PushGateway {
  Future<FirebaseMessaging?>? _messaging;

  Future<FirebaseMessaging?> _ready() => _messaging ??= () async {
        try {
          if (Firebase.apps.isEmpty) await Firebase.initializeApp();
          return FirebaseMessaging.instance;
        } catch (error) {
          debugPrint('push: Firebase is not available ($error); notifications are off');
          return null;
        }
      }();

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.denied || AuthorizationStatus.notDetermined => PushPermission.notAsked,
      };

  @override
  Future<PushPermission> permission() async {
    final m = await _ready();
    if (m == null) return PushPermission.unavailable;
    try {
      return _map((await m.getNotificationSettings()).authorizationStatus);
    } catch (_) {
      return PushPermission.unavailable;
    }
  }

  @override
  Future<PushPermission> requestPermission() async {
    final m = await _ready();
    if (m == null) return PushPermission.unavailable;
    try {
      return _map((await m.requestPermission()).authorizationStatus);
    } catch (_) {
      return PushPermission.unavailable;
    }
  }

  @override
  Future<String?> token() async {
    final m = await _ready();
    if (m == null || await permission() != PushPermission.granted) return null;
    try {
      // ignore: deprecated_member_use
      return await m.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh async* {
    final m = await _ready();
    // ignore: deprecated_member_use
    if (m != null) yield* m.onTokenRefresh;
  }

  @override
  Stream<PushMessage> get foreground async* {
    if (await _ready() != null) yield* FirebaseMessaging.onMessage.map(PushMessage.fromRemote);
  }

  @override
  Stream<PushMessage> get opened async* {
    if (await _ready() != null) yield* FirebaseMessaging.onMessageOpenedApp.map(PushMessage.fromRemote);
  }

  @override
  Future<PushMessage?> launchMessage() async {
    final m = await _ready();
    if (m == null) return null;
    try {
      final message = await m.getInitialMessage();
      return message == null ? null : PushMessage.fromRemote(message);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    final m = await _ready();
    if (m == null) return;
    try {
      // ignore: deprecated_member_use
      await m.deleteToken();
    } catch (_) {}
  }
}

final pushGatewayProvider = Provider<PushGateway>((ref) => FirebasePushGateway());
