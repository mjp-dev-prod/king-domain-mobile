import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/contract_history.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/screens/client/applicants_screen.dart';
import 'package:king_domain/presentation/screens/client/post_job_screen.dart';
import 'package:king_domain/presentation/screens/shell/client_jobs_tab.dart';
import 'package:king_domain/presentation/widgets/kit/kd_button.dart';

final _now = DateTime.now();

Job _job({
  String id = 'j1',
  String title = 'Logo and brand kit',
  int applicants = 0,
  DateTime? closedAt,
  ContractStatus? contract,
  String? awarded,
}) => Job(
  id: id,
  title: title,
  category: 'Design & creative',
  description: 'A long enough description of the work.',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(const Duration(days: 1)),
  applicationCount: applicants,
  closedAt: closedAt,
  contractStatus: contract,
  awardedApplicationId: awarded,
  deliveryDays: 5,
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    loading: false,
    user: AuthUser(id: 'c1', email: 'chinedu@example.com', role: 'client', fullName: 'Chinedu', emailVerified: true),
  );
}

class _Jobs extends JobsNotifier {
  _Jobs(this.jobs, {this.editError, this.closeError});
  final List<Job> jobs;
  final ApiException? editError;
  final ApiException? closeError;
  final calls = <String>[];

  @override
  Future<List<Job>> build() async => jobs;
  @override
  Future<List<JobApplication>> listApplications(String jobId) async => const [];
  @override
  Future<Job> editJob(String jobId, {required String title, required String category, required String description, required double budget, required int deliveryDays}) async {
    calls.add('edit:$title|$category|$description|${budget.round()}|$deliveryDays');
    if (editError != null) throw editError!;
    return jobs.first;
  }

  @override
  Future<void> closeJob(String jobId) async {
    calls.add('close:$jobId');
    if (closeError != null) throw closeError!;
  }
}

Future<void> _show(WidgetTester tester, Widget screen, _Jobs jobs) async {
  // Tall enough to build the whole edit form at once (a ListView builds lazily).
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      jobsProvider.overrideWith(() => jobs),
      contractHistoryProvider('j1').overrideWith((ref) async => const ContractHistory()),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
}

/// A home screen with one button that opens [next], so the tests can see a screen leave.
Widget _opener(Widget next) => Builder(
  builder: (c) => Scaffold(
    body: Center(
      child: TextButton(onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => next)), child: const Text('open')),
    ),
  ),
);

Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Finder _textFieldWith(String text) => find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

void main() {
  group('the manage menu on the applicants screen', () {
    testWidgets('an open job with no applicants offers Edit and Close', (tester) async {
      await _show(tester, ApplicantsScreen(job: _job()), _Jobs([_job()]));
      await tester.tap(find.byTooltip('Manage this job'));
      await tester.pumpAndSettle();
      expect(find.text('Edit job'), findsOneWidget);
      expect(find.text('Close job'), findsOneWidget);
      expect(find.text('Terms are locked'), findsNothing);
    });

    testWidgets('once someone has applied, Edit is replaced by why the terms are locked', (tester) async {
      await _show(tester, ApplicantsScreen(job: _job(applicants: 2)), _Jobs([_job(applicants: 2)]));
      await tester.tap(find.byTooltip('Manage this job'));
      await tester.pumpAndSettle();
      expect(find.text('Edit job'), findsNothing);
      expect(find.text('Terms are locked'), findsOneWidget);
      expect(find.textContaining('Close it and post a new one'), findsOneWidget);
      expect(find.text('Close job'), findsOneWidget);
    });

    testWidgets('an awarded job has no menu', (tester) async {
      final awarded = _job(contract: ContractStatus.awaitingPayment, awarded: 'a1');
      await _show(tester, ApplicantsScreen(job: awarded), _Jobs([awarded]));
      expect(find.byTooltip('Manage this job'), findsNothing);
    });

    testWidgets('a closed job has no menu', (tester) async {
      final closed = _job(closedAt: _now);
      await _show(tester, ApplicantsScreen(job: closed), _Jobs([closed]));
      expect(find.byTooltip('Manage this job'), findsNothing);
    });
  });

  group('closing a job', () {
    testWidgets('the confirmation says how many applicants will see it closed, then closes and leaves the screen', (tester) async {
      final jobs = _Jobs([_job(applicants: 3)]);
      await _show(tester, _opener(ApplicantsScreen(job: _job(applicants: 3))), jobs);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage this job'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close job'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 applicants'), findsOneWidget);
      expect(find.textContaining('can\'t be undone'), findsOneWidget);
      await tester.tap(find.widgetWithText(KdButton, 'Close job'));
      await tester.pumpAndSettle();
      expect(jobs.calls, ['close:j1']);
      expect(find.byType(ApplicantsScreen), findsNothing);
      await _drainToasts(tester);
    });

    testWidgets('a refusal from the server is shown and the screen stays', (tester) async {
      final jobs = _Jobs([_job()], closeError: ApiException('This job has already been awarded.', 409, code: 'awarded'));
      await _show(tester, ApplicantsScreen(job: _job()), jobs);
      await tester.tap(find.byTooltip('Manage this job'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close job'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(KdButton, 'Close job'));
      await tester.pumpAndSettle();
      expect(find.text('This job has already been awarded.'), findsOneWidget);
      expect(find.byType(ApplicantsScreen), findsOneWidget);
      await _drainToasts(tester);
    });
  });

  group('a closed job', () {
    testWidgets('the applicants screen is read-only and says it was closed', (tester) async {
      final closed = _job(closedAt: _now);
      await _show(tester, ApplicantsScreen(job: closed), _Jobs([closed]));
      expect(find.text('Closed'), findsOneWidget);
      expect(find.textContaining('You closed this job'), findsOneWidget);
    });
  });

  group('edit mode', () {
    testWidgets('opens filled with the job, saves the changes, and leaves', (tester) async {
      final jobs = _Jobs([_job()]);
      await _show(tester, _opener(PostJobScreen(editing: _job())), jobs);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Edit job'), findsOneWidget);
      expect(_textFieldWith('Logo and brand kit'), findsOneWidget);
      await tester.enterText(_textFieldWith('Logo and brand kit'), 'Logo, brand kit and guide');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(jobs.calls.single, 'edit:Logo, brand kit and guide|Design & creative|A long enough description of the work.|45000|5');
      expect(find.text('Save changes'), findsNothing);
      await _drainToasts(tester);
    });

    testWidgets('a locked job shows the server\'s reason and stays on the form', (tester) async {
      final jobs = _Jobs(
        [_job()],
        editError: ApiException('Someone has already applied, so the terms are locked. Close this job and post a new one to change them.', 409, code: 'has_applicants'),
      );
      await _show(tester, PostJobScreen(editing: _job()), jobs);
      await tester.tap(find.text('Save changes'));
      await tester.pump(const Duration(seconds: 1)); // the button holds its busy state for 300 ms
      await tester.pumpAndSettle();
      expect(find.textContaining('Someone has already applied'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('posting a new job is unchanged: the button still says Post job', (tester) async {
      await _show(tester, const Scaffold(body: PostJobScreen()), _Jobs([_job()]));
      expect(find.text('Post job'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
    });
  });

  group('the client\'s list', () {
    test('a closed job sorts after open ones', () {
      final open = _job();
      final closed = _job(id: 'j2', title: 'Old closed job', closedAt: _now);
      expect(ClientJobsTab.sorted([closed, open]).map((j) => j.id), ['j1', 'j2']);
    });

    testWidgets('a closed job shows a Closed pill and how many had applied', (tester) async {
      final closed = _job(title: 'Old closed job', applicants: 2, closedAt: _now);
      await _show(tester, Scaffold(body: ClientJobsTab(onPostJob: () {})), _Jobs([closed]));
      expect(find.text('Old closed job'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
      expect(find.text('Closed · 2 applicants'), findsOneWidget);
    });
  });
}
