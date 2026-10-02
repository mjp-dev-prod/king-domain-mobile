import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/contract_history.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/client/client_contract_screen.dart';
import 'package:king_domain/presentation/screens/contracts/contract_detail_screen.dart';

final _now = DateTime.now();

Job _job({
  required ContractStatus status,
  int extensionsUsed = 0,
  int changeRounds = 0,
  bool overdue = false,
  DateTime? changeDueAt,
  DateTime? reviewDueAt,
}) => Job(
  id: 'j1',
  title: 'Logo and brand kit',
  category: 'Design & creative',
  description: 'd',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(const Duration(days: 5)),
  contractStatus: status,
  deliveryDays: 5,
  fundedAt: _now.subtract(const Duration(days: 2)),
  deliverByAt: _now.add(const Duration(days: 3)),
  extensionsUsed: extensionsUsed,
  changeRounds: changeRounds,
  changeDueAt: changeDueAt,
  overdue: overdue,
  reviewDueAt: reviewDueAt,
);

ExtensionRequest _ext(ExtensionStatus status) => ExtensionRequest(
  id: 'x1',
  requestedDays: 2,
  reason: 'The menu photos arrived late.',
  status: status,
  requestedAt: _now.subtract(const Duration(hours: 1)),
  answerDueAt: _now.add(const Duration(hours: 47)),
);

class _Jobs extends JobsNotifier {
  _Jobs(this.job);
  final Job job;
  final calls = <String>[];

  @override
  Future<List<Job>> build() async => [job];

  @override
  Future<void> requestExtension(String jobId, {required int days, required String reason}) async => calls.add('extend:$days:$reason');
  @override
  Future<void> answerExtension(String jobId, String extensionId, {required bool grant}) async => calls.add('answer:$extensionId:$grant');
  @override
  Future<bool> requestChanges(String jobId, {required String reason}) async {
    calls.add('changes:$reason');
    return false;
  }
  @override
  Future<void> approveDelivery(String jobId) async => calls.add('approve');
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(payoutAccount: PayoutAccount(accountName: 'ADA OBI', accountNumberLast4: '6789'));
}

Future<_Jobs> _show(WidgetTester tester, Widget screen, Job job, {ContractHistory history = const ContractHistory()}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final jobs = _Jobs(job);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      jobsProvider.overrideWith(() => jobs),
      talentProfileProvider.overrideWith(_Profile.new),
      contractHistoryProvider('j1').overrideWith((ref) async => history),
    ],
    // Reduced motion: stops the looping "waiting" dot so pumpAndSettle can
    // settle, and exercises the reduced-motion path at the same time.
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
  return jobs;
}

/// Lets a toast's auto-dismiss timer run out, as it would on a phone.
Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  group('talent contract screen', () {
    testWidgets('in progress, no request yet: can ask for more time, sheet sends days and reason', (tester) async {
      final jobs = await _show(tester, const ContractDetailScreen(jobId: 'j1'), _job(status: ContractStatus.inProgress));

      expect(find.text('Ask for more time · 2 requests left'), findsOneWidget);
      await tester.tap(find.text('Ask for more time · 2 requests left'));
      await tester.pumpAndSettle();

      expect(find.text('Send request'), findsOneWidget);
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(jobs.calls, isEmpty, reason: 'disabled until a reason of 10+ characters is given');

      await tester.enterText(find.byType(TextField), 'The menu photos arrived late.');
      await tester.pump();
      await tester.tap(find.text('Send request'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(jobs.calls, ['extend:2:The menu photos arrived late.']);
      await _drainToasts(tester);
    });

    testWidgets('a pending request: shown with the auto-grant promise, and no second request', (tester) async {
      await _show(
        tester,
        const ContractDetailScreen(jobId: 'j1'),
        _job(status: ContractStatus.inProgress, extensionsUsed: 1),
        history: ContractHistory(extensions: [_ext(ExtensionStatus.pending)]),
      );

      expect(find.text('You asked for 2 more days'), findsOneWidget);
      expect(find.textContaining('it\'s granted automatically'), findsOneWidget);
      expect(find.text('Waiting on Chinedu\'s answer'), findsOneWidget);
    });

    testWidgets('both requests used: says so instead of offering a third', (tester) async {
      await _show(tester, const ContractDetailScreen(jobId: 'j1'), _job(status: ContractStatus.inProgress, extensionsUsed: 2));
      expect(find.text('No extension requests left'), findsOneWidget);
    });

    testWidgets('overdue: a red notice, and asking for time is closed', (tester) async {
      await _show(tester, const ContractDetailScreen(jobId: 'j1'), _job(status: ContractStatus.inProgress, overdue: true));
      expect(find.text('3 days past the delivery date'), findsOneWidget);
      expect(find.text('Too late: 3 days past the date'), findsOneWidget);
    });

    testWidgets('changes requested: round, the client\'s reason, the clock, and deliver version 2', (tester) async {
      await _show(
        tester,
        const ContractDetailScreen(jobId: 'j1'),
        _job(status: ContractStatus.changesRequested, changeRounds: 1, changeDueAt: _now.add(const Duration(days: 2))),
        history: ContractHistory(
          deliveries: [DeliveryVersion(version: 1, note: 'First pass', submittedAt: _now.subtract(const Duration(days: 1)))],
          changeRounds: [ChangeRound(round: 1, reason: 'Use the darker orange.', requestedAt: _now, resubmitDueAt: _now.add(const Duration(days: 2)))],
        ),
      );

      expect(find.text('Round 1 of 2'), findsOneWidget);
      expect(find.text('"Use the darker orange."'), findsOneWidget);
      expect(find.textContaining('Resubmit within'), findsOneWidget);
      expect(find.text('Deliver version 2'), findsOneWidget);
    });

    testWidgets('disputed: with an admin, nothing to do', (tester) async {
      await _show(tester, const ContractDetailScreen(jobId: 'j1'), _job(status: ContractStatus.disputed, changeRounds: 2));
      expect(find.textContaining('admin'), findsWidgets);
      expect(find.text('Deliver the work'), findsNothing);
    });
  });

  group('client contract screen', () {
    testWidgets('a pending extension: answer it from the card', (tester) async {
      final jobs = await _show(
        tester,
        const ClientContractScreen(jobId: 'j1'),
        _job(status: ContractStatus.inProgress, extensionsUsed: 1),
        history: ContractHistory(extensions: [_ext(ExtensionStatus.pending)]),
      );

      expect(find.text('The talent asked for 2 more days'), findsOneWidget);
      expect(find.textContaining('or it\'s granted automatically'), findsOneWidget);
      await tester.tap(find.text('Give 2 more days'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(jobs.calls, ['answer:x1:true']);
      await _drainToasts(tester);
    });

    testWidgets('declining asks first', (tester) async {
      final jobs = await _show(
        tester,
        const ClientContractScreen(jobId: 'j1'),
        _job(status: ContractStatus.inProgress, extensionsUsed: 1),
        history: ContractHistory(extensions: [_ext(ExtensionStatus.pending)]),
      );

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Decline the extension?'), findsOneWidget);
      expect(jobs.calls, isEmpty);

      await tester.tap(find.widgetWithText(GestureDetector, 'Decline').last);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(jobs.calls, ['answer:x1:false']);
      await _drainToasts(tester);
    });

    testWidgets('delivered: approving pays only after confirming', (tester) async {
      final jobs = await _show(
        tester,
        const ClientContractScreen(jobId: 'j1'),
        _job(status: ContractStatus.submitted),
        history: ContractHistory(deliveries: [DeliveryVersion(version: 1, note: 'Brand kit attached', submittedAt: _now)]),
      );

      expect(find.text('Brand kit attached'), findsOneWidget);
      await tester.tap(find.text('Approve and pay ₦45,000'));
      await tester.pumpAndSettle();
      expect(jobs.calls, isEmpty, reason: 'real money: a confirmation step first');

      await tester.tap(find.text('Approve and pay'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(jobs.calls, ['approve']);
      await _drainToasts(tester);
    });

    testWidgets('after round 2 the change action becomes asking an admin', (tester) async {
      await _show(tester, const ClientContractScreen(jobId: 'j1'), _job(status: ContractStatus.submitted, changeRounds: 2));
      expect(find.text('Still not right? Ask an admin'), findsOneWidget);
      await tester.tap(find.text('Still not right? Ask an admin'));
      await tester.pumpAndSettle();
      expect(find.text('Send to an admin'), findsOneWidget);
    });

    testWidgets('overdue: says so plainly and promises no refund yet', (tester) async {
      await _show(tester, const ClientContractScreen(jobId: 'j1'), _job(status: ContractStatus.inProgress, overdue: true));
      expect(find.text('3 days past the delivery date'), findsOneWidget);
      expect(find.textContaining('isn\'t available in the app yet'), findsOneWidget);
    });
  });
}
