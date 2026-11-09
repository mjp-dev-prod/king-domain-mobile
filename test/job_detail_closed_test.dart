import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'discovery_test_support.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/jobs/job_detail_screen.dart';

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
      ...discoveryStubs(),
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

}
