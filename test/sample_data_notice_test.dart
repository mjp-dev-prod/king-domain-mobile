import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/common/sample_data_notice.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.theme, home: Scaffold(body: child));

void main() {
  testWidgets('shows nothing for live data', (tester) async {
    await tester.pumpWidget(_host(const SampleDataNotice(source: DataSource.live, what: 'Disputes')));
    expect(find.textContaining('Sample data'), findsNothing);
  });

  testWidgets('says plainly that the data is a sample and what is not connected', (tester) async {
    await tester.pumpWidget(_host(const SampleDataNotice(source: DataSource.sample, what: 'Disputes')));
    expect(find.text('Sample data'), findsOneWidget);
    expect(find.textContaining("Disputes isn't connected to the server yet"), findsOneWidget);
  });
}
