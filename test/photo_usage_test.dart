import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/contract_history.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/data/models/skill_submission.dart';
import 'package:king_domain/presentation/providers/identity_provider.dart';
import 'package:king_domain/presentation/providers/skill_submissions_provider.dart';
import 'package:king_domain/data/models/identity.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/client/applicants_screen.dart';
import 'package:king_domain/presentation/screens/jobs/job_detail_screen.dart';
import 'package:king_domain/presentation/screens/profile/profile_photo_button.dart';
import 'package:king_domain/presentation/screens/shell/profile_tabs.dart';

/// Wherever a person is shown, their photo is shown when they have one.
final _now = DateTime.now();

Job _job({String? clientPhotoUrl}) => Job(
  id: 'j1',
  title: 'Logo and brand kit',
  category: 'Design & creative',
  description: 'A long enough description of the work.',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  clientPhotoUrl: clientPhotoUrl,
  postedAt: _now,
  applicationCount: 1,
  deliveryDays: 5,
);

class _Auth extends AuthNotifier {
  _Auth(this.role, this.photoUrl);
  final String role;
  final String? photoUrl;
  @override
  AuthState build() => AuthState(
    loading: false,
    user: AuthUser(id: 'u1', email: 'x@uni.edu.ng', role: role, fullName: 'Ada Obi', emailVerified: true, photoUrl: photoUrl),
  );
}

class _Jobs extends JobsNotifier {
  _Jobs(this.jobs, {this.apps = const []});
  final List<Job> jobs;
  final List<JobApplication> apps;
  @override
  Future<List<Job>> build() async => jobs;
  @override
  Future<List<JobApplication>> listApplications(String jobId) async => apps;
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(headline: 'Brand designer', bio: 'b', skillCategories: ['Design & creative']);
}

Future<void> _show(WidgetTester tester, Widget screen, {String role = 'talent', String? photoUrl, List<Job> jobs = const [], List<JobApplication> apps = const []}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _Auth(role, photoUrl)),
      jobsProvider.overrideWith(() => _Jobs(jobs, apps: apps)),
      talentProfileProvider.overrideWith(_Profile.new),
      identityProvider.overrideWith((ref) async => const IdentitySummary(status: IdentityStatus.notStarted, minor: false, guardianNeeded: false, canTransact: false, requiredForPaidActions: false)),
      aboutYouProvider.overrideWith((ref) async => const AboutYou()),
      skillHubProvider.overrideWith((ref) async => const SkillHub(skills: [], uploadsAvailable: true)),
      contractHistoryProvider('j1').overrideWith((ref) async => const ContractHistory()),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: Scaffold(body: screen),
    ),
  ));
  await tester.pumpAndSettle();
}

Iterable<String> _imageUrls(WidgetTester tester) => tester.widgetList<Image>(find.byType(Image)).map((i) => (i.image as NetworkImage).url);

void main() {
  testWidgets('an applicant\'s photo shows on their card, and one without a photo shows initials', (tester) async {
    final job = _job();
    await _show(
      tester,
      ApplicantsScreen(job: job),
      role: 'client',
      jobs: [job],
      apps: [
        JobApplication(id: 'a1', jobId: 'j1', talentId: 't1', talentName: 'Ada Obi', talentPhotoUrl: 'https://files.test/avatars/ada.png', status: 'pending', createdAt: _now),
        JobApplication(id: 'a2', jobId: 'j1', talentId: 't2', talentName: 'Bola Ade', status: 'pending', createdAt: _now),
      ],
    );
    expect(_imageUrls(tester), ['https://files.test/avatars/ada.png']);
    expect(find.text('BA'), findsOneWidget);
    expect(find.text('AO'), findsOneWidget, reason: 'initials sit under a photo while it loads');
  });

  testWidgets('the client\'s photo shows on the job a talent is looking at', (tester) async {
    await _show(tester, const JobDetailScreen(jobId: 'j1'), jobs: [_job(clientPhotoUrl: 'https://files.test/avatars/chinedu.jpg')]);
    expect(_imageUrls(tester), contains('https://files.test/avatars/chinedu.jpg'));
  });

  testWidgets('a client with no photo shows initials on the job', (tester) async {
    await _show(tester, const JobDetailScreen(jobId: 'j1'), jobs: [_job()]);
    expect(find.text('C'), findsWidgets);
    expect(_imageUrls(tester), isEmpty);
  });

  testWidgets('the talent\'s own profile has the photo button, with their photo', (tester) async {
    await _show(tester, const TalentProfileTab(), photoUrl: 'https://files.test/avatars/me.png');
    expect(find.byType(ProfilePhotoButton), findsOneWidget);
    expect(_imageUrls(tester), contains('https://files.test/avatars/me.png'));
  });

  testWidgets('the client\'s own profile has the photo button too', (tester) async {
    await _show(tester, const ClientProfileTab(), role: 'client');
    expect(find.byType(ProfilePhotoButton), findsOneWidget);
    expect(find.text('AO'), findsOneWidget);
  });
}
