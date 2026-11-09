import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'discovery_test_support.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/data/models/skill_submission.dart';
import 'package:king_domain/presentation/providers/identity_provider.dart';
import 'package:king_domain/presentation/providers/skill_submissions_provider.dart';
import 'package:king_domain/data/models/identity.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/providers/sent_work_provider.dart';
import 'package:king_domain/presentation/screens/shell/app_shell.dart';
import 'package:king_domain/presentation/screens/skills/sent_work_screen.dart';

final _now = DateTime.now();

Job _job(String id, {String category = 'Design & creative', String? skillKey = 'graphic-design', ContractStatus? contract, JobApplicationStatus app = JobApplicationStatus.notApplied, String? awarded}) => Job(
  id: id,
  title: 'Job $id',
  category: category,
  skillKey: skillKey,
  skillLabel: skillKey,
  description: 'd',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(const Duration(hours: 2)),
  contractStatus: contract,
  applicationStatus: app,
  awardedApplicationId: awarded,
  deliveryDays: 5,
  deliverByAt: _now.add(const Duration(days: 3)),
);

class _Auth extends AuthNotifier {
  bool signedOut = false;
  @override
  AuthState build() => const AuthState(
    loading: false,
    user: AuthUser(id: 't1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true),
  );
  @override
  Future<void> logout() async => signedOut = true;
}

class _Jobs extends JobsNotifier {
  _Jobs(this.jobs);
  final List<Job> jobs;
  @override
  Future<List<Job>> build() async => jobs;
}

const _fullProfile = TalentProfile(
  headline: 'Brand designer',
  bio: 'b',
  skillCategories: ['Design & creative'],
  payoutAccount: PayoutAccount(accountName: 'ADA OBI', accountNumberLast4: '6789'),
);

const _verifiedGraphic = SkillHub(
  uploadsAvailable: true,
  skills: [SkillHubEntry(skillKey: 'graphic-design', label: 'Graphic design', category: 'Design & creative', state: SkillState.verified, currentSubmissionId: 's1', attempts: 1, restriction: null, rubricDraft: false)],
);

class _Profile extends TalentProfileNotifier {
  _Profile([this.profile = _fullProfile]);
  final TalentProfile profile;
  @override
  Future<TalentProfile> build() async => profile;
}

Future<_Auth> _shell(WidgetTester tester, List<Job> jobs, {SkillHub hub = _verifiedGraphic, TalentProfile profile = _fullProfile}) async {
  // 360 x 866 logical: the narrowest common Android width.
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final auth = _Auth();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(() => auth),
      jobsProvider.overrideWith(() => _Jobs(jobs)),
      ...discoveryStubs(feed: [for (final j in jobs) if (j.awardedApplicationId == null || j.applicationStatus != JobApplicationStatus.notApplied) j]),
      talentProfileProvider.overrideWith(() => _Profile(profile)),
      identityProvider.overrideWith((ref) async => const IdentitySummary(status: IdentityStatus.notStarted, minor: false, guardianNeeded: false, canTransact: false, requiredForPaidActions: false)),
      aboutYouProvider.overrideWith((ref) async => const AboutYou()),
      skillHubProvider.overrideWith((ref) async => hub),
      sentWorkProvider('s1').overrideWith((ref) async => throw Exception('not needed here')),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const AppShell(),
    ),
  ));
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('feed: says plainly whether you can apply, for each job the server sends', (tester) async {
    await _shell(tester, [
      _job('a'),
      _job('b', category: 'Software & tech', skillKey: 'web-development'),
      _job('c', awarded: 'someone-else'),
    ]);

    expect(find.text('Job a'), findsOneWidget);
    expect(find.text('You qualify'), findsOneWidget, reason: 'verified in Graphic design');
    expect(find.text('Needs verified proof'), findsOneWidget, reason: 'not verified in Web development');
    expect(find.text('Job b'), findsOneWidget);
    // Which jobs appear is the server's call now (filters, paging, jobs filled by someone else): see the backend suite.
  });

  testWidgets('Work tab: empty state explains itself and goes to jobs', (tester) async {
    await _shell(tester, [_job('a')]);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('No work yet'), findsOneWidget);
    await tester.tap(find.text('Browse jobs'));
    await tester.pumpAndSettle();
    expect(find.text('Jobs for you'), findsOneWidget);
  });

  testWidgets('Work tab: lists awarded jobs with the next step, and the tab counts what needs you', (tester) async {
    await _shell(tester, [
      _job('w1', contract: ContractStatus.changesRequested, app: JobApplicationStatus.accepted, awarded: 'x'),
      _job('w2', contract: ContractStatus.submitted, app: JobApplicationStatus.accepted, awarded: 'x'),
      _job('other', contract: ContractStatus.inProgress, app: JobApplicationStatus.rejected, awarded: 'y'),
    ]);
    expect(find.text('1'), findsOneWidget, reason: 'badge: one contract needs the talent (changes requested)');

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('1 needs you'), findsOneWidget);
    expect(find.text('Job w1'), findsOneWidget);
    expect(find.text('Job w2'), findsOneWidget);
    expect(find.text('Job other'), findsNothing, reason: 'someone else\'s contract');
    expect(find.textContaining('Changes requested · resubmit within'), findsOneWidget);
  });

  testWidgets('sign out asks first', (tester) async {
    final auth = await _shell(tester, [_job('a')]);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Settings'), 200, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    expect(auth.signedOut, isFalse);

    await tester.tap(find.text('Sign out').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isTrue);
  });

  group('the verified badge on the profile', () {
    testWidgets('names the skill that was verified, and is not a work category picked at sign-up', (tester) async {
      await _shell(tester, [_job('a')]);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Graphic design verified'), findsOneWidget);
      expect(find.text('Design & creative verified'), findsNothing, reason: 'a category is not a verification');
    });

    testWidgets('someone with no verified skill gets no badge, even with categories picked, and is told to get verified', (tester) async {
      await _shell(tester, [_job('a')], hub: const SkillHub(skills: [], uploadsAvailable: true));
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r' verified$')), findsNothing, reason: 'no "<skill> verified" badge: nothing was earned');
      expect(find.text('Get verified in a skill'), findsOneWidget);
    });

    testWidgets('a skill that is only in review is not a badge', (tester) async {
      const inReview = SkillHub(
        uploadsAvailable: true,
        skills: [SkillHubEntry(skillKey: 'web-development', label: 'Web development', category: 'Software & tech', state: SkillState.inReview, currentSubmissionId: 's2', attempts: 1, restriction: null, rubricDraft: false)],
      );
      await _shell(tester, [_job('a')], hub: inReview);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Web development verified'), findsNothing);
    });

    testWidgets('tapping it shows what was verified, not a setup stepper', (tester) async {
      await _shell(tester, [_job('a')]);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Graphic design verified'));
      await tester.pumpAndSettle();
      expect(find.byType(SentWorkScreen), findsOneWidget);
      expect(find.textContaining('of 3 done'), findsNothing, reason: 'the old three-step screen is gone');
    });

    testWidgets('once profile, a verified skill and payout are all done there is no nag card', (tester) async {
      await _shell(tester, [_job('a')]);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Get verified in a skill'), findsNothing);
      expect(find.text('Finish your profile'), findsNothing);
      expect(find.text('Add a payout account'), findsNothing);
    });

    testWidgets('the next step follows the order that unlocks the most: profile, then skill, then payout', (tester) async {
      await _shell(tester, [_job('a')], hub: const SkillHub(skills: [], uploadsAvailable: true), profile: const TalentProfile());
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Finish your profile'), findsOneWidget);
      expect(find.text('Get verified in a skill'), findsNothing, reason: 'one thing at a time');
    });
  });
}
