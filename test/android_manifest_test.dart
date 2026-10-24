import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// A release build only gets the permissions the MAIN manifest declares. The
/// debug and profile manifests add INTERNET automatically (for hot reload), so
/// `flutter run` works while a built APK silently has no network at all and
/// every request fails with "Could not reach the server". Both CI workflows run
/// this before building.
void main() {
  test('the main Android manifest declares the INTERNET permission', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"'),
      reason: 'release APKs would have no network access',
    );
  });

  // Pushes are addressed to a channel by name, in three places that must agree: the backend sender
  // (king-domain-backend/src/push.js CHANNEL_ID), the default channel in the manifest, and the channel
  // MainActivity creates. If they drift, Android shows pushes in a catch-all channel or drops them.
  test('the push channel is named the same in the manifest and in MainActivity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final activity = File('android/app/src/main/kotlin/com/kingdomain/king_domain/MainActivity.kt').readAsStringSync();
    expect(
      manifest,
      matches(RegExp(r'default_notification_channel_id"\s+android:value="kd_updates"')),
      reason: 'the default channel in the manifest',
    );
    expect(activity, contains('NotificationChannel("kd_updates"'), reason: 'the channel MainActivity creates');
  });

  test('push sets its notification icon and colour, and the POST_NOTIFICATIONS permission is declared', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('@drawable/ic_stat_kd'));
    expect(manifest, contains('@color/kd_notification'));
    expect(File('android/app/src/main/res/drawable/ic_stat_kd.xml').existsSync(), isTrue);
    expect(File('android/app/src/main/res/values/colors.xml').readAsStringSync(), contains('kd_notification'));
  });

  test('the Firebase config is never committed (the repo is public)', () {
    final ignore = File('.gitignore').readAsStringSync();
    expect(ignore, contains('android/app/src/*/google-services.json'));
  });
}
