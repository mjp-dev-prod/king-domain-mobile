import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/formatting/deadline.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/client/review_deliverable_screen.dart';
import 'package:king_domain/presentation/screens/contracts/contract_detail_screen.dart';
import 'package:king_domain/presentation/screens/payments/fund_contract_screen.dart';

Job _job({ContractStatus? status, DateTime? payByAt, DateTime? reviewDueAt}) => Job(
  id: 'j1',
  title: 'Logo for a campus startup',
  category: 'Design & creative',
  description: 'd',
  budget: 5000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: DateTime(2026, 10, 1),
  contractStatus: status,
  platformFeeAmount: 500,
  payByAt: payByAt,
  reviewDueAt: reviewDueAt,
  deliverableNote: 'Final files attached',
);

class _Jobs extends JobsNotifier {
  _Jobs(this.job);
  final Job job;

  @override
  Future<List<Job>> build() async => [job];
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(
    payoutAccount: PayoutAccount(accountName: 'ADA OBI', accountNumberLast4: '6789'),
  );
}

Future<void> _show(WidgetTester tester, Widget screen, Job job) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      jobsProvider.overrideWith(() => _Jobs(job)),
      talentProfileProvider.overrideWith(_Profile.new),
    ],
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('timeLeft', () {
    final now = DateTime(2026, 10, 1, 12);

    test('hours and minutes inside a day', () {
      expect(timeLeft(now.add(const Duration(hours: 23, minutes: 58)), now: now), '23h 58m');
    });
    test('days and hours beyond a day', () {
      expect(timeLeft(now.add(const Duration(days: 2, hours: 4, minutes: 10)), now: now), '2 days 4h');
      expect(timeLeft(now.add(const Duration(days: 1, hours: 1)), now: now), '1 day 1h');
    });
    test('minutes under an hour, and under a minute', () {
      expect(timeLeft(now.add(const Duration(minutes: 12, seconds: 5)), now: now), '12 min');
      expect(timeLeft(now.add(const Duration(seconds: 20)), now: now), 'less than a minute');
    });
    test('null once the deadline has passed', () {
      expect(timeLeft(now.subtract(const Duration(seconds: 1)), now: now), isNull);
    });
  });

  group('client payment screen', () {
    testWidgets('shows the 24h deadline and what happens if it is missed', (tester) async {
      await _show(
        tester,
        const FundContractScreen(jobId: 'j1'),
        _job(status: ContractStatus.awaitingPayment, payByAt: DateTime.now().add(const Duration(hours: 23, minutes: 30))),
      );

      expect(find.textContaining('Pay within 23h'), findsOneWidget);
      expect(find.textContaining('award is cancelled'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).onPressed, isNotNull);
    });

    testWidgets('after the window: says so and the Pay button is disabled', (tester) async {
      await _show(
        tester,
        const FundContractScreen(jobId: 'j1'),
        _job(status: ContractStatus.awaitingPayment, payByAt: DateTime.now().subtract(const Duration(minutes: 3))),
      );

      expect(find.textContaining('payment window has ended'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton).first).onPressed, isNull);
    });

    testWidgets('award cancelled while the screen was open: explains and offers no payment', (tester) async {
      await _show(tester, const FundContractScreen(jobId: 'j1'), _job(status: null));

      expect(find.textContaining('cancelled because it wasn\'t paid for within 24 hours'), findsOneWidget);
      expect(find.textContaining('Pay ₦'), findsNothing);
    });
  });

  group('talent contract screen', () {
    testWidgets('awaiting payment: tells the talent the deadline and that they stay in the running', (tester) async {
      await _show(
        tester,
        const ContractDetailScreen(jobId: 'j1'),
        _job(status: ContractStatus.awaitingPayment, payByAt: DateTime.now().add(const Duration(hours: 5))),
      );

      expect(find.textContaining('back in the running'), findsOneWidget);
    });

    testWidgets('submitted, auto-release on (server sent a date): promises automatic payment', (tester) async {
      await _show(
        tester,
        const ContractDetailScreen(jobId: 'j1'),
        _job(status: ContractStatus.submitted, reviewDueAt: DateTime.now().add(const Duration(days: 3))),
      );

      expect(find.textContaining('you\'re paid automatically'), findsOneWidget);
    });

    testWidgets('submitted, auto-release off (no date from the server): promises nothing automatic', (tester) async {
      await _show(tester, const ContractDetailScreen(jobId: 'j1'), _job(status: ContractStatus.submitted));

      expect(find.textContaining('paid automatically'), findsNothing);
    });
  });

  group('client review screen', () {
    testWidgets('warns that doing nothing releases payment, with the date', (tester) async {
      await _show(
        tester,
        const ReviewDeliverableScreen(jobId: 'j1'),
        _job(status: ContractStatus.submitted, reviewDueAt: DateTime.now().add(const Duration(days: 3))),
      );

      expect(find.textContaining('If you do nothing, payment is released'), findsOneWidget);
    });

    testWidgets('no warning when auto-release is off', (tester) async {
      await _show(tester, const ReviewDeliverableScreen(jobId: 'j1'), _job(status: ContractStatus.submitted));

      expect(find.textContaining('If you do nothing'), findsNothing);
    });
  });
}
