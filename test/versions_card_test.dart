import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/contract_history.dart';
import 'package:king_domain/presentation/widgets/contract/contract_parts.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Delivered files are reached through links that expire after 5 minutes. A
/// screen left open longer must not open a dead link: it asks for fresh ones.
class _Launcher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

DeliveryVersion _v(int n, String link, {String? note}) =>
    DeliveryVersion(version: n, note: note ?? 'v$n', fileUrl: link, submittedAt: DateTime(2026, 10, 2));

Future<void> _show(WidgetTester tester, Widget card) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
    home: Scaffold(body: SingleChildScrollView(child: card)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  late _Launcher launcher;
  setUp(() {
    launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
  });

  testWidgets('"Open the file" asks for fresh links first and opens the fresh one, not the expired one', (tester) async {
    var refreshes = 0;
    await _show(
      tester,
      VersionsCard(
        title: 'Delivered work',
        versions: [_v(1, 'https://files.test/expired/flyer.pdf?token=old')],
        refreshLinks: () async {
          refreshes++;
          return [_v(1, 'https://files.test/fresh/flyer.pdf?token=new')];
        },
      ),
    );
    await tester.tap(find.text('Open the file'));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    expect(launcher.launched, ['https://files.test/fresh/flyer.pdf?token=new']);
  });

  testWidgets('it opens the right version when several exist', (tester) async {
    await _show(
      tester,
      VersionsCard(
        title: 'Delivered work',
        versions: [_v(1, 'https://files.test/old/1.pdf'), _v(2, 'https://files.test/old/2.pdf')],
        refreshLinks: () async => [_v(1, 'https://files.test/new/1.pdf'), _v(2, 'https://files.test/new/2.pdf')],
      ),
    );
    await tester.tap(find.textContaining('Version 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open the file'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['https://files.test/new/1.pdf']);
  });

  testWidgets('if refreshing fails (offline), it still tries the link it has', (tester) async {
    await _show(
      tester,
      VersionsCard(
        title: 'Delivered work',
        versions: [_v(1, 'https://files.test/held/flyer.pdf')],
        refreshLinks: () async => throw Exception('offline'),
      ),
    );
    await tester.tap(find.text('Open the file'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['https://files.test/held/flyer.pdf']);
  });

  testWidgets('a plain web link in a delivery is opened as it is, with no refresh', (tester) async {
    var refreshes = 0;
    await _show(
      tester,
      VersionsCard(
        title: 'Delivered work',
        versions: [
          DeliveryVersion(version: 1, note: 'n', url: 'https://drive.google.com/file/d/abc', submittedAt: DateTime(2026, 10, 2)),
        ],
        refreshLinks: () async {
          refreshes++;
          return [];
        },
      ),
    );
    await tester.tap(find.text('https://drive.google.com/file/d/abc'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['https://drive.google.com/file/d/abc']);
    expect(refreshes, 0, reason: 'a normal link does not expire');
  });

  testWidgets('an image that keeps failing triggers ONE refresh, never a loop', (tester) async {
    // Like the real screen: a refresh puts a NEW link on screen. The test
    // environment answers every network image with an error, so that new link
    // fails too, which is exactly what could loop without the guard.
    var refreshes = 0;
    final shown = ValueNotifier<List<DeliveryVersion>>([_v(1, 'https://files.test/expired/flyer.png?token=old')]);
    addTearDown(shown.dispose);
    await _show(
      tester,
      ValueListenableBuilder<List<DeliveryVersion>>(
        valueListenable: shown,
        builder: (_, versions, _) => VersionsCard(
          title: 'Delivered work',
          versions: versions,
          refreshLinks: () async {
            refreshes++;
            shown.value = [_v(1, 'https://files.test/expired/flyer.png?token=bad$refreshes')];
            return shown.value;
          },
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(refreshes, 1, reason: 'the broken image must refresh once, not again and again');
  });
}
