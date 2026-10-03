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
}
