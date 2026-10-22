import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/widgets/contract/lifecycle_stepper.dart';
import 'package:king_domain/presentation/widgets/kit/kd_card.dart';
import 'package:king_domain/presentation/widgets/kit/status_pill.dart';

final _now = DateTime.now();

Job _job(ContractStatus s, {bool overdue = false, int changeRounds = 0, DateTime? payByAt, DateTime? deliverByAt, DateTime? reviewDueAt}) => Job(
  id: 'j1',
  title: 'Logo',
  category: 'Design & creative',
  description: 'd',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now,
  contractStatus: s,
  platformFeeAmount: 4500,
  deliveryDays: 5,
  overdue: overdue,
  changeRounds: changeRounds,
  payByAt: payByAt,
  deliverByAt: deliverByAt,
  reviewDueAt: reviewDueAt,
);

List<StepProgress> _progress(List<LifecycleStep> s) => s.map((e) => e.progress).toList();
const D = StepProgress.done, C = StepProgress.current, L = StepProgress.later;

void main() {
  group('which steps are done, current and later', () {
    final table = <ContractStatus, List<StepProgress>>{
      ContractStatus.awaitingPayment: [D, C, L, L, L],
      ContractStatus.funded: [D, D, C, L, L],
      ContractStatus.inProgress: [D, D, C, L, L],
      ContractStatus.changesRequested: [D, D, C, L, L],
      ContractStatus.submitted: [D, D, D, C, L],
      ContractStatus.disputed: [D, D, D, C, L],
      ContractStatus.approved: [D, D, D, D, D],
    };
    for (final e in table.entries) {
      for (final forClient in [false, true]) {
        test('${e.key.name} as ${forClient ? 'client' : 'talent'}', () {
          expect(_progress(lifecycleSteps(_job(e.key), forClient: forClient)), e.value);
        });
      }
    }
  });

  group('labels', () {
    test('five steps; the last one is worded for the viewer', () {
      final talent = lifecycleSteps(_job(ContractStatus.funded), forClient: false).map((s) => s.label).toList();
      expect(talent, ['Awarded', 'Payment secured', 'Working on it', 'Client reviews', 'You\'re paid']);
      final client = lifecycleSteps(_job(ContractStatus.funded), forClient: true).map((s) => s.label).toList();
      expect(client.last, 'Talent is paid');
    });
  });

  group('tone of the current step', () {
    KdTone tone(ContractStatus s, {required bool forClient, bool overdue = false}) =>
        lifecycleSteps(_job(s, overdue: overdue), forClient: forClient).firstWhere((x) => x.progress == StepProgress.current).tone;

    test('violet when it is your turn, amber when you are waiting', () {
      expect(tone(ContractStatus.awaitingPayment, forClient: true), KdTone.brand);
      expect(tone(ContractStatus.awaitingPayment, forClient: false), KdTone.warn);
      expect(tone(ContractStatus.funded, forClient: false), KdTone.brand);
      expect(tone(ContractStatus.funded, forClient: true), KdTone.warn);
      expect(tone(ContractStatus.inProgress, forClient: false), KdTone.brand);
      expect(tone(ContractStatus.inProgress, forClient: true), KdTone.warn);
      expect(tone(ContractStatus.submitted, forClient: true), KdTone.brand);
      expect(tone(ContractStatus.submitted, forClient: false), KdTone.warn);
      expect(tone(ContractStatus.changesRequested, forClient: false), KdTone.brand);
      expect(tone(ContractStatus.changesRequested, forClient: true), KdTone.warn);
    });

    test('red for a dispute and for a missed delivery date', () {
      expect(tone(ContractStatus.disputed, forClient: true), KdTone.bad);
      expect(tone(ContractStatus.inProgress, forClient: false, overdue: true), KdTone.bad);
    });
  });

  group('subtitles use real data and say nothing about where money is held', () {
    String? sub(Job j, int i, {required bool forClient}) => lifecycleSteps(j, forClient: forClient)[i].subtitle;

    test('awaiting payment: the client is told how long they have, the talent who they wait for', () {
      final j = _job(ContractStatus.awaitingPayment, payByAt: _now.add(const Duration(hours: 23, minutes: 30)));
      expect(sub(j, 1, forClient: true), startsWith('Pay within 23h'));
      expect(sub(j, 1, forClient: false), 'Waiting for Chinedu to pay');
    });

    test('paid: says who paid, with the total the client paid on the client side', () {
      final j = _job(ContractStatus.funded);
      expect(sub(j, 1, forClient: false), 'Chinedu has paid');
      expect(sub(j, 1, forClient: true), contains('₦49,500'));
    });

    test('in progress shows the time left, or the missed date when overdue', () {
      final due = _job(ContractStatus.inProgress, deliverByAt: _now.add(const Duration(days: 2, hours: 1)));
      expect(sub(due, 2, forClient: false), startsWith('Due in 2 days'));
      final late = _job(ContractStatus.inProgress, overdue: true, deliverByAt: _now.subtract(const Duration(days: 4)));
      expect(sub(late, 2, forClient: false), '3 days past the delivery date');
    });

    test('changes requested names the round', () {
      final j = _job(ContractStatus.changesRequested, changeRounds: 1);
      expect(sub(j, 2, forClient: false), 'Changes requested, round 1 of 2');
    });

    test('in review: the talent waits for the client; the client is told to review; a later step explains the window', () {
      final j = _job(ContractStatus.submitted, reviewDueAt: _now.add(const Duration(days: 3)));
      expect(sub(j, 3, forClient: true), 'Review it now');
      expect(sub(j, 3, forClient: false), startsWith('Waiting for Chinedu'));
      final working = _job(ContractStatus.inProgress);
      expect(sub(working, 3, forClient: false), 'Up to 3 days to approve or ask for changes');
    });

    test('disputed is with an admin; the last step reads as a payout, not a holding', () {
      expect(sub(_job(ContractStatus.disputed), 3, forClient: true), 'With a King Domain admin');
      expect(sub(_job(ContractStatus.approved), 4, forClient: false), 'Paid to your payout account');
      expect(sub(_job(ContractStatus.approved), 4, forClient: true), 'Paid out to the talent');
      for (final s in ContractStatus.values) {
        for (final c in [false, true]) {
          for (final step in lifecycleSteps(_job(s), forClient: c)) {
            expect(step.subtitle ?? '', isNot(contains('held')), reason: '${s.name} ${step.label}');
          }
        }
      }
    });
  });

  group('the widget', () {
    Future<void> show(WidgetTester tester, Job job, {required bool forClient, bool reduceMotion = true}) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
        home: Scaffold(body: SingleChildScrollView(child: LifecycleStepper(job: job, forClient: forClient))),
      ));
      await tester.pump();
    }

    testWidgets('shows all five labels', (tester) async {
      await show(tester, _job(ContractStatus.inProgress, deliverByAt: _now.add(const Duration(days: 2))), forClient: false);
      for (final l in ['Awarded', 'Payment secured', 'Working on it', 'Client reviews', 'You\'re paid']) {
        expect(find.text(l), findsOneWidget);
      }
    });

    testWidgets('each step announces its position and state to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, _job(ContractStatus.submitted), forClient: false);
      expect(find.bySemanticsLabel(RegExp(r'^Step 3 of 5: Working on it, done')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Step 4 of 5: Client reviews, current')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Step 5 of 5: You.re paid, later')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a step the viewer is waiting on pulses when motion is allowed', (tester) async {
      await show(tester, _job(ContractStatus.submitted), forClient: false, reduceMotion: false);
      expect(find.byType(PulseDot), findsOneWidget);
    });

    testWidgets('a finished contract has nothing pulsing', (tester) async {
      await show(tester, _job(ContractStatus.approved), forClient: false, reduceMotion: false);
      expect(find.byType(PulseDot), findsNothing);
    });
  });
}
