import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/evidence_viewer.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.theme, home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  test('formats sizes the way people read them', () {
    expect(formatBytes(900), '900 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(48 * 1024 * 1024), '48 MB');
    expect(formatBytes((1.5 * 1024 * 1024 * 1024).round()), '1.5 GB');
  });

  testWidgets('a video shows its size and opens only when tapped', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_host(EvidenceViewer(
      open: (u) async => opened.add(u),
      items: const [EvidenceItem(kind: EvidenceKind.video, label: 'Rough cut', url: 'https://cdn.example/cut.mp4', sizeBytes: 48 * 1024 * 1024)],
    )));
    expect(find.text('Rough cut'), findsOneWidget);
    expect(find.textContaining('48 MB'), findsOneWidget);
    expect(opened, isEmpty, reason: 'nothing loads on its own');
    await tester.tap(find.text('Rough cut'));
    await tester.pump();
    expect(opened.single.toString(), 'https://cdn.example/cut.mp4');
  });

  testWidgets('text evidence shows inline, and an empty list says so', (tester) async {
    await tester.pumpWidget(_host(const EvidenceViewer(items: [EvidenceItem(kind: EvidenceKind.text, label: 'Outline', text: '1. Hook\n2. Story')])));
    expect(find.textContaining('1. Hook'), findsOneWidget);
    await tester.pumpWidget(_host(const EvidenceViewer(items: [])));
    expect(find.text('Nothing attached'), findsOneWidget);
  });
}
