import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/jobs/job_detail_screen.dart';
import 'package:king_domain/presentation/screens/jobs/job_feed_screen.dart';

final _now = DateTime.now();

Job _job({
  String id = 'j1',
  String title = 'Logo and brand kit',
  int revision = 0,
  DateTime? closedAt,
  JobApplicationStatus app = JobApplicationStatus.notApplied,
}) => Job(
  id: id,
  title: title,
  category: 'Design & creative',
  description: 'A long enough description of the work.',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(const Duration(hours: 3)),
  revision: revision,
  closedAt: closedAt,
  applicationStatus: app,
  deliveryDays: 5,
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    loading: false,
    user: AuthUser(id: 't1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true),
  );
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(
    headline: 'Brand designer',
    bio: 'b',
    skillCategories: ['Design & creative'],
    proofItems: [ProofItem(id: 'p1', category: 'Design & creative', title: 'Campus café logo', status: ProofReviewStatus.verified)],
    payoutAccount: PayoutAccount(accountName: 'ADA OBI', accountNumberLast4: '6789'),
  );
}

class _Jobs extends JobsNotifier {
  _Jobs(this.jobs, {this.applyError});
  final List<Job> jobs;
  final ApiException? applyError;
  final calls = <String>[];
  int refreshes = 0;

  @override
  Future<List<Job>> build() async => jobs;
  @override
  Future<void> refresh() async => refreshes++;
  @override
  Future<void> applyTo(String jobId, {int? revision}) async {
    calls.add('apply:$jobId:$revision');
    if (applyError != null) throw applyError!;
  }
}

Future<_Jobs> _show(WidgetTester tester, Widget screen, List<Job> jobs, {ApiException? applyError}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final notifier = _Jobs(jobs, applyError: applyError);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(_Auth.new),
      jobsProvider.overrideWith(() => notifier),
      talentProfileProvider.overrideWith(_Profile.new),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
  return notifier;
}

Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Future<void> _applyThroughTheSheet(WidgetTester tester) async {
  await tester.tap(find.text('Apply for this job'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send application'));
  await tester.pump(const Duration(seconds: 1)); // the button holds its busy state for 300 ms
  await tester.pumpAndSettle();
}

void main() {
  group('a closed job', () {
    testWidgets('says it is closed and offers no way to apply', (tester) async {
      await _show(tester, const JobDetailScreen(jobId: 'j1'), [_job(closedAt: _now)]);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('This job is closed'), findsOneWidget);
      expect(find.textContaining('Chinedu closed it'), findsOneWidget);
      expect(find.text('Apply for this job'), findsNothing);
      expect(find.text('You can apply'), findsNothing);
    });

    testWidgets('an applicant whose job closed sees Closed, not an open application', (tester) async {
      await _show(tester, const JobDetailScreen(jobId: 'j1'), [_job(closedAt: _now, app: JobApplicationStatus.rejected)]);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Not selected'), findsNothing);
    });
  });

  group('applying', () {
    testWidgets('sends the revision of the job the talent read', (tester) async {
      final jobs = await _show(tester, const JobDetailScreen(jobId: 'j1'), [_job(revision: 2)]);
      await _applyThroughTheSheet(tester);
      expect(jobs.calls, ['apply:j1:2']);
      await _drainToasts(tester);
    });

    testWidgets('edited terms: the job is re-read, the sheet closes, and the talent is told, with no error shown', (tester) async {
      final jobs = await _show(
        tester,
        const JobDetailScreen(jobId: 'j1'),
        [_job(revision: 1)],
        applyError: ApiException('This job was just edited. Read the new details, then apply again.', 409, code: 'terms_changed'),
      );
      await _applyThroughTheSheet(tester);
      expect(jobs.refreshes, 1);
      expect(find.text('Send application'), findsNothing);
      expect(find.text('This job was just edited. Check the new details, then apply again.'), findsOneWidget);
      await _drainToasts(tester);
    });

    testWidgets('any other refusal is shown in the sheet and the sheet stays', (tester) async {
      await _show(
        tester,
        const JobDetailScreen(jobId: 'j1'),
        [_job()],
        applyError: ApiException('You\'ve already applied to this job.', 409, code: 'already_applied'),
      );
      await _applyThroughTheSheet(tester);
      expect(find.text('You\'ve already applied to this job.'), findsOneWidget);
      expect(find.text('Send application'), findsOneWidget);
      await _drainToasts(tester);
    });
  });

  group('the feed', () {
    testWidgets('hides a closed job the talent never applied to, and keeps one they applied to', (tester) async {
      await _show(tester, const Scaffold(body: JobFeedScreen()), [
        _job(id: 'open', title: 'Open job'),
        _job(id: 'closed-never', title: 'Closed, never applied', closedAt: _now),
        _job(id: 'closed-applied', title: 'Closed, I applied', closedAt: _now, app: JobApplicationStatus.rejected),
      ]);
      expect(find.text('Open job'), findsOneWidget);
      expect(find.text('Closed, I applied'), findsOneWidget);
      expect(find.text('Closed, never applied'), findsNothing);
    });
  });
}
