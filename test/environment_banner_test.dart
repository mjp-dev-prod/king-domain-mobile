import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/presentation/widgets/common/environment_banner.dart';

Widget _app({required String? host, double statusBarInset = 24}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(padding: EdgeInsets.only(top: statusBarInset)),
    child: EnvironmentBanner(host: host, child: child!),
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(child: Text('top inset seen by screen: ${MediaQuery.of(context).padding.top}')),
    ),
  ),
);

void main() {
  testWidgets('production (no host): nothing is added and the screen keeps its status-bar inset', (tester) async {
    await tester.pumpWidget(_app(host: null));

    expect(find.textContaining('TEST SERVER'), findsNothing);
    expect(find.text('top inset seen by screen: 24.0'), findsOneWidget);
  });

  testWidgets('test server: banner names the host and sits below the status bar', (tester) async {
    await tester.pumpWidget(_app(host: '192.168.1.12:4000'));

    expect(find.text('TEST SERVER · 192.168.1.12:4000'), findsOneWidget);
    final bannerTop = tester.getTopLeft(find.byType(Material).first).dy;
    final textTop = tester.getTopLeft(find.text('TEST SERVER · 192.168.1.12:4000')).dy;
    expect(bannerTop, 0);
    expect(textTop, greaterThanOrEqualTo(24));
  });

  testWidgets('test server: screens below drop their inset so the gap is not doubled', (tester) async {
    await tester.pumpWidget(_app(host: '10.0.2.2:4000'));

    expect(find.text('top inset seen by screen: 0.0'), findsOneWidget);
  });
}
