import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/job_lifecycles.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/kd_stepper.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.theme, home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  test('each job type has the steps the PRD gives it', () {
    expect(lifecycleLabels(JobKind.oneDelivery), ['Agreed', 'Funded', 'Start proof', 'Working', 'Delivered', 'Review', 'Approved', 'Paid']);
    expect(lifecycleLabels(JobKind.milestones), ['Funded', 'Working', 'Delivered', 'Review', 'Paid']);
    expect(lifecycleLabels(JobKind.monthly), ['Month funded', 'Working', "Month's deliveries", 'Review', 'Paid']);
    expect(lifecycleLabels(JobKind.hourly), ['Week funded', 'Hours reported', 'Approve or dispute', 'Paid']);
  });

  testWidgets('shows every step and announces position and state', (tester) async {
    final steps = [
      const KdStep(label: 'Funded', state: KdStepState.done),
      const KdStep(label: 'Start proof', subtitle: 'Waiting for the client', state: KdStepState.waiting),
      const KdStep(label: 'Working', state: KdStepState.later),
    ];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(KdStepper(steps: steps)));
    expect(find.text('Funded'), findsOneWidget);
    expect(find.text('Waiting for the client'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3: Start proof, waiting on someone'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'the done step shows a check');
    handle.dispose();
  });
}
