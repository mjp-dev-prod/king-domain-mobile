import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/app_brand.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/contract_history.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/screens/client/applicants_screen.dart';
import 'package:king_domain/presentation/screens/contracts/submit_deliverable_screen.dart';

final _now = DateTime.now();

Job _job({ContractStatus? status, String? awarded, int changeRounds = 0, DateTime? changeDueAt}) => Job(
  id: 'j1',
  title: 'Logo and brand kit',
  category: 'Design & creative',
  description: 'd',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(const Duration(days: 5)),
  contractStatus: status,
  awardedApplicationId: awarded,
  applicationCount: 2,
  deliveryDays: 5,
  changeRounds: changeRounds,
  changeDueAt: changeDueAt,
);

JobApplication _app(String id, String name, {String status = 'pending', ApplicantSignals signals = const ApplicantSignals()}) =>
    JobApplication(id: id, jobId: 'j1', talentId: 't$id', talentName: name, status: status, createdAt: _now, signals: signals);

class _Jobs extends JobsNotifier {
  _Jobs(this.job, {this.apps = const []});
  final Job job;
  final List<JobApplication> apps;
  final calls = <String>[];

  @override
  Future<List<Job>> build() async => [job];
  @override
  Future<List<JobApplication>> listApplications(String jobId) async => apps;
  @override
  Future<void> awardApplication(String jobId, String applicationId) async => calls.add('award:$applicationId');
  @override
  Future<String?> startFunding(String jobId) async => null;
  @override
  Future<void> submitDeliverable(String jobId, String note, {String? url, List<int>? fileBytes, String? fileName}) async =>
      calls.add('submit:$note:$url:${fileName ?? '-'}');
}

Future<void> _show(WidgetTester tester, Widget screen, _Jobs jobs, {ContractHistory history = const ContractHistory()}) async {
  // 360 x 866 logical: the narrowest common Android width.
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      jobsProvider.overrideWith(() => jobs),
      contractHistoryProvider('j1').overrideWith((ref) async => history),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  test('applicant signals parse from the API, and default to nothing when absent', () {
    final a = JobApplication.fromJson({
      'id': 'a1',
      'jobId': 'j1',
      'status': 'pending',
      'createdAt': '2026-10-01T10:00:00Z',
      'talent': {'id': 't1', 'fullName': 'Ada Obi'},
      'signals': {
        'headline': 'Brand designer',
        'verifiedInCategory': true,
        'proof': [{'id': 'p1', 'title': 'Cafe logo', 'fileUrl': 'https://x.test/a.png'}],
        'jobsCompleted': 3,
      },
    });
    expect(a.signals.headline, 'Brand designer');
    expect(a.signals.verifiedInCategory, isTrue);
    expect(a.signals.proof.single.title, 'Cafe logo');
    expect(a.signals.jobsCompleted, 3);

    final bare = JobApplication.fromJson({'id': 'a2', 'jobId': 'j1', 'talent': {'id': 't2', 'fullName': 'Tobi'}});
    expect(bare.signals.verifiedInCategory, isFalse);
    expect(bare.signals.proof, isEmpty);
  });

  group('applicants', () {
    final apps = [
      _app('a1', 'Ada Obi', signals: const ApplicantSignals(headline: 'Brand designer', verifiedInCategory: true, jobsCompleted: 2, proof: [(id: 'p1', title: 'Cafe logo', fileUrl: null)])),
      _app('a2', 'Tobi Lawal'),
    ];

    testWidgets('shows real signals only, in applied order, with no ranking', (tester) async {
      await _show(tester, ApplicantsScreen(job: _job()), _Jobs(_job(), apps: apps));

      expect(find.textContaining('doesn\'t rank applicants'), findsOneWidget);
      expect(find.text('Verified in this category'), findsOneWidget);
      expect(find.text('Not verified in this category'), findsOneWidget);
      expect(find.text('2 jobs done'), findsOneWidget);
      expect(find.text('New to ${AppBrand.name}'), findsOneWidget);
      expect(find.text('Brand designer'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Ada Obi')).dy, lessThan(tester.getTopLeft(find.text('Tobi Lawal')).dy));
      expect(find.textContaining('match', findRichText: true), findsNothing);
    });

    testWidgets('picking asks first, then awards that one applicant', (tester) async {
      final jobs = _Jobs(_job(), apps: apps);
      await _show(tester, ApplicantsScreen(job: _job()), jobs);

      await tester.tap(find.text('Pick Tobi'));
      await tester.pumpAndSettle();
      expect(jobs.calls, isEmpty, reason: 'the sheet confirms before anything is sent');
      expect(find.textContaining('24 hours'), findsOneWidget);

      await tester.tap(find.text('Pick Tobi Lawal'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(jobs.calls, ['award:a2']);
    });

    testWidgets('once someone is picked: no more pick buttons, the rest show not selected', (tester) async {
      final awarded = _job(awarded: 'a1', status: ContractStatus.awaitingPayment);
      await _show(tester, ApplicantsScreen(job: awarded), _Jobs(awarded, apps: [
        _app('a1', 'Ada Obi', status: 'selected'),
        _app('a2', 'Tobi Lawal', status: 'notSelected'),
      ]));
      expect(find.text('Picked'), findsOneWidget);
      expect(find.text('Not selected'), findsOneWidget);
      expect(find.textContaining('Pick '), findsNothing);
    });

    testWidgets('no applicants: says why and what happens next', (tester) async {
      await _show(tester, ApplicantsScreen(job: _job()), _Jobs(_job()));
      expect(find.text('No applicants yet'), findsOneWidget);
    });
  });

  group('deliver', () {
    testWidgets('needs a note and the work; a non-web link is refused before sending', (tester) async {
      final jobs = _Jobs(_job(status: ContractStatus.inProgress));
      await _show(tester, const SubmitDeliverableScreen(jobId: 'j1'), jobs);

      expect(find.text('Add an image or a link to deliver.'), findsOneWidget);
      await tester.tap(find.text('Deliver for review'));
      await tester.pumpAndSettle();
      expect(jobs.calls, isEmpty);

      await tester.enterText(find.byType(TextField).first, 'javascript:alert(1)');
      await tester.pump();
      expect(find.text('Use a full web address starting with https://'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'https://drive.google.com/file/d/abc');
      await tester.enterText(find.byType(TextField).last, 'Final logo files');
      await tester.pump();
      expect(find.text('Add an image or a link to deliver.'), findsNothing);

      await tester.tap(find.text('Deliver for review'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(jobs.calls, ['submit:Final logo files:https://drive.google.com/file/d/abc:-']);
      await _drainToasts(tester);
    });

    testWidgets('a resubmission shows what the client asked for and the next version number', (tester) async {
      final job = _job(status: ContractStatus.changesRequested, changeRounds: 1, changeDueAt: _now.add(const Duration(days: 2)));
      await _show(
        tester,
        const SubmitDeliverableScreen(jobId: 'j1'),
        _Jobs(job),
        history: ContractHistory(
          deliveries: [DeliveryVersion(version: 1, note: 'v1', submittedAt: _now.subtract(const Duration(days: 1)))],
          changeRounds: [ChangeRound(round: 1, reason: 'Make the mark work in one colour.', requestedAt: _now, resubmitDueAt: _now.add(const Duration(days: 2)))],
        ),
      );
      expect(find.text('Deliver the revised version'), findsOneWidget);
      expect(find.textContaining('Make the mark work in one colour.'), findsOneWidget);
      expect(find.text('Round 1 of 2'), findsOneWidget);
      expect(find.text('Deliver version 2'), findsOneWidget);
    });
  });

  test('web link check matches the backend rule', () {
    for (final ok in ['https://drive.google.com/x', 'http://figma.com/file/1']) {
      expect(SubmitDeliverableScreen.isWebLink(ok), isTrue, reason: ok);
    }
    for (final bad in ['javascript:alert(1)', 'file:///etc/passwd', 'https://', 'drive.google.com/x', 'intent://x#Intent;end']) {
      expect(SubmitDeliverableScreen.isWebLink(bad), isFalse, reason: bad);
    }
  });
}
