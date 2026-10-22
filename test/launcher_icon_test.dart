import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The launcher icon and the launch screen live in Android resources, so a widget test can't see
/// them. This checks the files themselves: every density at the right pixel size, one icon per
/// flavor (so KD Staging is told apart from King Domain on the home screen), and a launch screen
/// that is the brand's dark ground, not Flutter's default white flash.
const _res = 'android/app/src/main/res';
const _stagingRes = 'android/app/src/staging/res';

const _legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
const _foreground = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432};

/// Width and height from a PNG's header (the IHDR chunk), or null when it isn't a PNG.
({int w, int h})? _pngSize(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final b = file.readAsBytesSync();
  if (b.length < 24 || b[0] != 0x89 || b[1] != 0x50 || b[2] != 0x4e || b[3] != 0x47) return null;
  final d = ByteData.sublistView(Uint8List.fromList(b.sublist(16, 24)));
  return (w: d.getUint32(0), h: d.getUint32(4));
}

String _read(String path) => File(path).existsSync() ? File(path).readAsStringSync() : '';

void main() {
  for (final entry in {'production (main)': _res, 'staging': _stagingRes}.entries) {
    group('${entry.key} icon', () {
      for (final d in _legacy.entries) {
        test('ic_launcher.png is ${d.value}px in ${d.key}', () {
          final s = _pngSize('${entry.value}/mipmap-${d.key}/ic_launcher.png');
          expect(s, isNotNull, reason: 'missing or not a PNG');
          expect((s!.w, s.h), (d.value, d.value));
        });
      }
      for (final d in _foreground.entries) {
        test('ic_launcher_foreground.png is ${d.value}px in ${d.key}', () {
          final s = _pngSize('${entry.value}/mipmap-${d.key}/ic_launcher_foreground.png');
          expect(s, isNotNull, reason: 'missing or not a PNG');
          expect((s!.w, s.h), (d.value, d.value));
        });
      }
    });
  }

  group('adaptive icon', () {
    final xml = _read('$_res/mipmap-anydpi-v26/ic_launcher.xml');
    test('has a background colour, a foreground, and a monochrome layer for themed icons', () {
      expect(xml, contains('<adaptive-icon'));
      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('<foreground android:drawable="@mipmap/ic_launcher_foreground"'));
      expect(xml, contains('<monochrome android:drawable="@mipmap/ic_launcher_foreground"'));
    });
  });

  group('colours', () {
    test('production sits on the brand ground', () {
      expect(_read('$_res/values/ic_launcher_background.xml').toLowerCase(), contains('#0d0a16'));
    });
    test('staging is violet, so it is never mistaken for production', () {
      expect(_read('$_stagingRes/values/ic_launcher_background.xml').toLowerCase(), contains('#7451f2'));
    });
  });

  group('launch screen', () {
    test('is the brand ground with the mark, not the default white', () {
      final launch = _read('$_res/drawable/launch_background.xml');
      expect(launch, isNot(contains('@android:color/white')));
      expect(launch, contains('@color/ic_launcher_background'));
      expect(launch, contains('@mipmap/ic_launcher_foreground'));
    });

    test('Android 12 and later get the same background and mark', () {
      final v31 = _read('$_res/values-v31/styles.xml');
      expect(v31, contains('android:windowSplashScreenBackground'));
      expect(v31, contains('@color/ic_launcher_background'));
      expect(v31, contains('android:windowSplashScreenAnimatedIcon'));
    });
  });
}
