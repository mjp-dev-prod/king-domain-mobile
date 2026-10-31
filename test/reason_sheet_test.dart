import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/reason_sheet.dart';

const _codes = [
  ReasonCode(code: 'not_brief', label: 'Not what the brief said'),
  ReasonCode(code: 'other', label: 'Something else', needsNote: true),
];

void main() {
  testWidgets('confirm stays disabled until a reason is picked, and a note is required when the reason needs one', (tester) async {
    ReasonChoice? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showReasonSheet(context, title: 'Why?', codes: _codes, confirmLabel: 'Send'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'no reason picked yet');

    await tester.tap(find.text('Something else'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'this reason needs a note');

    await tester.enterText(find.byType(TextField), 'The colours are off-brand.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(result?.code, 'other');
    expect(result?.note, 'The colours are off-brand.');
  });
}
