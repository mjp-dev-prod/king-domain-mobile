import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/consent_screen.dart';

const _details = ConsentDetails(
  title: 'Check your identity',
  purpose: 'To confirm you are who you say you are before you can be paid.',
  collected: ['Your NIN', 'A live selfie'],
  whoSees: 'Our identity provider and the King Domain checker. Never other users.',
  keptFor: 'The result for as long as you have an account; the selfie is not kept.',
  rights: 'You can ask what we hold, correct it, or delete your account at any time.',
  agreeLabel: 'I agree to this check',
);

void main() {
  testWidgets('starts unticked, says what is collected and why, and only continues once ticked', (tester) async {
    var agreed = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: ConsentScreen(details: _details, onAgree: () async => agreed++)));
    expect(find.text('Your NIN'), findsOneWidget);
    expect(find.textContaining('Never other users'), findsOneWidget);
    final box = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(box.value, isFalse, reason: 'consent is never pre-ticked');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(agreed, 0);

    await tester.tap(find.text('I agree to this check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(agreed, 1);
  });
}
