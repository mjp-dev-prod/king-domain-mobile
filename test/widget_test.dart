import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:king_domain/main.dart';

void main() {
  testWidgets('Welcome screen leads into sign-up email validation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: KingDomainApp()),
    );

    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });
}
