import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/app_motion.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/kd_button.dart';
import 'package:king_domain/presentation/widgets/kit/kd_fields.dart';
import 'package:king_domain/presentation/widgets/kit/kd_toast.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.theme,
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: Center(child: child))),
);

void main() {
  group('KdButton', () {
    testWidgets('a fast action still shows the spinner for the minimum hold, then success, then idle', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_host(KdButton(label: 'Send', successLabel: 'Sent', onPressed: () async => calls++)));

      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'spinner shows while working');

      await tester.pump(AppMotion.minLoading - const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'held even though the work finished instantly');

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(milliseconds: 600));
      expect(find.text('Sent'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Send'), findsOneWidget);
      expect(calls, 1);
    });

    testWidgets('a second tap while working does nothing', (tester) async {
      var calls = 0;
      final gate = Completer<void>();
      await tester.pumpWidget(_host(KdButton(label: 'Pay', onPressed: () { calls++; return gate.future; })));

      await tester.tap(find.text('Pay'));
      await tester.pump();
      await tester.tap(find.byType(KdButton));
      await tester.pump();
      expect(calls, 1);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a failing action returns to idle and reports the error (never stuck spinning)', (tester) async {
      await tester.pumpWidget(_host(KdButton(label: 'Approve', onPressed: () async => throw StateError('boom'))));

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<StateError>());
      expect(find.text('Approve'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('no handler: disabled, tapping does nothing', (tester) async {
      await tester.pumpWidget(_host(const KdButton(label: 'Deliver', onPressed: null)));
      await tester.tap(find.text('Deliver'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ReasonField', () {
    testWidgets('says how many characters are still needed and reports validity', (tester) async {
      final c = TextEditingController();
      final valid = <bool>[];
      await tester.pumpWidget(_host(ReasonField(controller: c, label: 'Why?', onValidChanged: valid.add)));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'abcd');
      await tester.pump();
      expect(find.text('6 more characters'), findsOneWidget);
      expect(valid.last, isFalse);

      await tester.enterText(find.byType(TextField), 'Photos arrived late.');
      await tester.pump();
      expect(find.textContaining('more character'), findsNothing);
      expect(valid.last, isTrue);
    });

    test('limits match the backend (10 to 1000, trimmed)', () {
      expect(ReasonField.isValid('         x'), isFalse);
      expect(ReasonField.isValid('0123456789'), isTrue);
      expect(ReasonField.isValid('a' * 1001), isFalse);
    });
  });

  testWidgets('DayStepper stays inside its bounds', (tester) async {
    int? changed;
    await tester.pumpWidget(_host(DayStepper(value: 1, min: 1, max: 5, onChanged: (v) => changed = v)));

    await tester.tap(find.bySemanticsLabel('Fewer days'));
    await tester.pump();
    expect(changed, isNull, reason: 'already at the minimum');

    await tester.tap(find.bySemanticsLabel('More days'));
    await tester.pump();
    expect(changed, 2);
  });

  group('KdToast', () {
    testWidgets('one at a time: a new toast replaces the current one', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_host(Builder(builder: (c) { ctx = c; return const SizedBox(); })));

      KdToast.show(ctx, 'First');
      await tester.pump();
      KdToast.show(ctx, 'Second');
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);

      await tester.pump(AppMotion.toast);
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsNothing, reason: 'auto-dismisses');
    });

    testWidgets('an action runs and dismisses the toast', (tester) async {
      late BuildContext ctx;
      var undone = false;
      await tester.pumpWidget(_host(Builder(builder: (c) { ctx = c; return const SizedBox(); })));

      KdToast.show(ctx, 'Application sent', actionLabel: 'Undo', onAction: () => undone = true);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(undone, isTrue);
      expect(find.text('Application sent'), findsNothing);
    });
  });
}
