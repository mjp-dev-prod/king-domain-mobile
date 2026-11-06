import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'discovery_test_support.dart';
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
import 'package:king_domain/presentation/providers/push_gateway.dart';
import 'package:king_domain/presentation/providers/push_service.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/client/client_contract_screen.dart';
import 'package:king_domain/presentation/screens/contracts/contract_detail_screen.dart';
import 'package:king_domain/presentation/screens/shell/app_shell.dart';

import 'push_fakes.dart';

/// What a person sees: the one-time explanation, a push that arrives while the app is open, a tap that
/// opens the job, and the Notifications row on the profile (docs/features/push-notifications.md).
final _now = DateTime.now();

Job _job(String id, {ContractStatus? contract, JobApplicationStatus app = JobApplicationStatus.notApplied, String clientId = 'c1'}) => Job(
      id: id,
      title: 'Logo and brand kit',
      category: 'Design & creative',
      description: 'd',
      budget: 45000,
      clientId: clientId,
      clientName: 'Chinedu',
      postedAt: _now.subtract(const Duration(hours: 2)),
      contractStatus: contract,
      applicationStatus: app,
      awardedApplicationId: contract == null ? null : 'a1',
      deliveryDays: 5,
      deliverByAt: _now.add(const Duration(days: 3)),
    );

class _Auth extends AuthNotifier {
  _Auth(this.role);
  final String role;
  @override
  AuthState build() => AuthState(loading: false, user: AuthUser(id: role == 'client' ? 'c1' : 't1', email: 'x@uni.edu.ng', role: role, fullName: 'Ada Obi', emailVerified: true));
}

class _Jobs extends JobsNotifier {
  _Jobs(this.jobs);
  final List<Job> jobs;
  @override
  Future<List<Job>> build() async => jobs;
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(headline: 'h', bio: 'b', skillCategories: ['Design & creative'], proofItems: []);
}

late FakeGateway _gateway;
late FakeServer _server;

Future<void> _shell(WidgetTester tester, {String role = 'talent', List<Job>? jobs, PushPermission permission = PushPermission.notAsked}) async {
  _gateway = FakeGateway()..permissionNow = permission;
  _server = FakeServer();
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _Auth(role)),
      jobsProvider.overrideWith(() => _Jobs(jobs ?? [_job('j1')])),
      ...discoveryStubs(),
      talentProfileProvider.overrideWith(_Profile.new),
      identityProvider.overrideWith((ref) async => const IdentitySummary(status: IdentityStatus.notStarted, minor: false, guardianNeeded: false, canTransact: false, requiredForPaidActions: false)),
      aboutYouProvider.overrideWith((ref) async => const AboutYou()),
      skillHubProvider.overrideWith((ref) async => const SkillHub(skills: [], uploadsAvailable: true)),
      pushGatewayProvider.overrideWithValue(_gateway),
      pushServerProvider.overrideWithValue(_server),
      contractHistoryProvider('j1').overrideWith((ref) async => const ContractHistory()),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const AppShell(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('the explanation', () {
    testWidgets('appears once after sign-in; Turn on asks Android and registers the phone', (tester) async {
      await _shell(tester);
      expect(find.text('Stay in the loop'), findsOneWidget);
      expect(_gateway.requests, 0, reason: 'nothing is asked before the person chooses');

      _gateway.grantsOnRequest = PushPermission.granted;
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(_gateway.requests, 1);
      expect(_server.registered, ['tok-fake']);
      expect(find.text('Stay in the loop'), findsNothing);
    });

    testWidgets('Not now asks nothing, and is remembered', (tester) async {
      await _shell(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(_gateway.requests, 0);
      expect(_server.registered, isEmpty);

      // The shell is rebuilt (a restart): it must not ask again.
      await _shell(tester);
      expect(find.text('Stay in the loop'), findsNothing);
    });

    testWidgets('someone who already allowed pushes is not asked, and the phone is registered', (tester) async {
      await _shell(tester, permission: PushPermission.granted);
      expect(find.text('Stay in the loop'), findsNothing);
      expect(_server.registered, ['tok-fake']);
    });

    testWidgets('a phone without Firebase is left alone: no sheet, no row', (tester) async {
      await _shell(tester, permission: PushPermission.unavailable);
      expect(find.text('Stay in the loop'), findsNothing);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Settings'), 200, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out'), findsOneWidget, reason: 'Settings opened');
      expect(find.text('Notifications'), findsNothing);
    });
  });

  group('a push', () {
    testWidgets('that arrives while the app is open shows as a toast', (tester) async {
      await _shell(tester, permission: PushPermission.granted);
      _gateway.foregroundMessages.add(const PushMessage(title: 'Payment received', body: '"Logo and brand kit" is paid for.', data: {'type': 'funded', 'jobId': 'j1'}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Payment received'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // let the toast's timer run out
      await tester.pumpAndSettle();
    });

    testWidgets('tapped while the app was in the background opens the contract, for a talent with the job', (tester) async {
      await _shell(tester, permission: PushPermission.granted, jobs: [_job('j1', contract: ContractStatus.inProgress, app: JobApplicationStatus.accepted)]);
      _gateway.openedMessages.add(const PushMessage(title: 'Changes requested', body: 'b', data: {'type': 'changes_requested', 'jobId': 'j1'}));
      await tester.pumpAndSettle();
      expect(find.byType(ContractDetailScreen), findsOneWidget);
    });

    testWidgets('tapped to start the app (it was closed) opens the same place', (tester) async {
      _gateway = FakeGateway()
        ..permissionNow = PushPermission.granted
        ..launch = const PushMessage(title: 'x', body: 'y', data: {'type': 'submitted', 'jobId': 'j1'});
      _server = FakeServer();
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _Auth('client')),
          jobsProvider.overrideWith(() => _Jobs([_job('j1', contract: ContractStatus.submitted)])),
          ...discoveryStubs(),
          pushGatewayProvider.overrideWithValue(_gateway),
          pushServerProvider.overrideWithValue(_server),
        ],
        child: MaterialApp(theme: AppTheme.theme, home: const AppShell()),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ClientContractScreen), findsOneWidget);
    });

    testWidgets('for a job the person cannot see (gone, or not theirs) just stays where they are', (tester) async {
      await _shell(tester, permission: PushPermission.granted);
      _gateway.openedMessages.add(const PushMessage(title: 't', body: 'b', data: {'type': 'funded', 'jobId': 'does-not-exist'}));
      await tester.pumpAndSettle();
      expect(find.byType(ContractDetailScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });
  });

  group('the Notifications row', () {
    Future<void> toProfile(WidgetTester tester) async {
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      // The list builds rows beyond the screen, so "found" is not "on screen": bring it into view.
      await tester.scrollUntilVisible(find.text('Settings'), 200, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
    }

    testWidgets('says On when allowed', (tester) async {
      await _shell(tester, permission: PushPermission.granted);
      await toProfile(tester);
      expect(find.textContaining('On. We tell you'), findsOneWidget);
    });

    testWidgets('offers to turn on when the person said Not now, and asks Android when tapped', (tester) async {
      await _shell(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      await toProfile(tester);
      expect(find.textContaining('tap to turn on'), findsOneWidget);
      _gateway.grantsOnRequest = PushPermission.granted;
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(_gateway.requests, 1);
      expect(_server.registered, ['tok-fake']);
    });

    testWidgets('when refused, says where to turn it on in the phone\'s settings', (tester) async {
      await _shell(tester, permission: PushPermission.denied);
      await toProfile(tester);
      expect(find.textContaining('phone\'s settings'), findsWidgets);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Apps'), findsOneWidget);
      expect(_gateway.requests, 0, reason: 'Android will not ask again, so we do not pretend to');
    });
  });
}
