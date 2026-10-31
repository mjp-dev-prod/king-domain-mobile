import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/data/models/skill_submission.dart';
import 'package:king_domain/presentation/providers/identity_provider.dart';
import 'package:king_domain/presentation/providers/skill_submissions_provider.dart';
import 'package:king_domain/data/models/identity.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/onboarding/sign_up_screen.dart';
import 'package:king_domain/presentation/screens/shell/profile_tabs.dart';

/// Account deletion in the app (docs/features/account-deletion-and-privacy.md): the rows on the
/// profile, the sheet that asks for the password, and what each answer from the server looks like.
final _deleteCalls = <String>[];
ApiException? _deleteError;

class _Auth extends AuthNotifier {
  _Auth(this.role);
  final String role;
  @override
  AuthState build() => AuthState(loading: false, user: AuthUser(id: 'u1', email: 'x@uni.edu.ng', role: role, fullName: 'Ada Obi', emailVerified: true));
  @override
  Future<void> deleteAccount(String password) async {
    _deleteCalls.add(password);
    if (_deleteError != null) throw _deleteError!;
  }

  @override
  Future<void> logout() async => state = const AuthState(loading: false);
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(headline: 'Brand designer', bio: 'b', skillCategories: ['Design & creative'], proofItems: []);
}

Future<ProviderContainer> _show(WidgetTester tester, Widget screen, {String role = 'client'}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    authProvider.overrideWith(() => _Auth(role)),
    talentProfileProvider.overrideWith(_Profile.new),
    identityProvider.overrideWith((ref) async => const IdentitySummary(status: IdentityStatus.notStarted, minor: false, guardianNeeded: false, canTransact: false, requiredForPaidActions: false)),
    aboutYouProvider.overrideWith((ref) async => const AboutYou()),
    skillHubProvider.overrideWith((ref) async => const SkillHub(skills: [], uploadsAvailable: true)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: Scaffold(body: screen),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Delete account'), 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Delete account'));
  await tester.pumpAndSettle();
}

Future<void> _typePasswordAndDelete(WidgetTester tester, String password) async {
  if (password.isNotEmpty) await tester.enterText(find.byType(TextFormField), password);
  await tester.tap(find.text('Delete my account'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _deleteCalls.clear();
    _deleteError = null;
  });

  group('the profile', () {
    testWidgets('a client sees Privacy policy, Sign out and Delete account', (tester) async {
      await _show(tester, const ClientProfileTab());
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('a talent sees them too', (tester) async {
      await _show(tester, const TalentProfileTab(), role: 'talent');
      await tester.scrollUntilVisible(find.text('Delete account'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });
  });

  group('the sheet', () {
    testWidgets('says what is deleted and what is kept, and asks for the password (hidden)', (tester) async {
      await _show(tester, const ClientProfileTab());
      await _openSheet(tester);
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.textContaining('This can\'t be undone'), findsOneWidget);
      expect(find.textContaining('kept without your name'), findsOneWidget);
      expect(find.textContaining('job in progress'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    });

    testWidgets('an empty password is stopped on the phone, with a reason, and nothing is sent', (tester) async {
      await _show(tester, const ClientProfileTab());
      await _openSheet(tester);
      await _typePasswordAndDelete(tester, '');
      expect(find.text('Enter your password to confirm.'), findsOneWidget);
      expect(_deleteCalls, isEmpty);
    });

    testWidgets('a wrong password is shown in the sheet, which stays open, and nobody is signed out', (tester) async {
      _deleteError = ApiException('That password is incorrect.', 403, code: 'wrong_password');
      final container = await _show(tester, const ClientProfileTab());
      await _openSheet(tester);
      await _typePasswordAndDelete(tester, 'nope');
      expect(find.text('That password is incorrect.'), findsOneWidget);
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(container.read(authProvider).user, isNotNull);
    });

    testWidgets('an unreachable server is said plainly, and the account is untouched', (tester) async {
      _deleteError = ApiException('Could not reach the server.', 0);
      final container = await _show(tester, const ClientProfileTab());
      await _openSheet(tester);
      await _typePasswordAndDelete(tester, 'secret');
      expect(find.text('Could not reach the server.'), findsOneWidget);
      expect(container.read(authProvider).user, isNotNull);
    });

    testWidgets('an active contract lists the jobs and offers no delete button', (tester) async {
      _deleteError = ApiException('You have a job in progress.', 409, code: 'active_contracts', data: {
        'contracts': [
          {'jobId': 'j1', 'title': 'Logo and brand kit', 'role': 'client', 'status': 'inProgress'},
          {'jobId': 'j2', 'title': 'Poster', 'role': 'talent', 'status': 'submitted'},
        ],
      });
      final container = await _show(tester, const ClientProfileTab());
      await _openSheet(tester);
      await _typePasswordAndDelete(tester, 'secret');
      expect(find.text('Finish these first'), findsOneWidget);
      expect(find.text('Logo and brand kit'), findsOneWidget);
      expect(find.textContaining('In progress'), findsOneWidget);
      expect(find.text('Poster'), findsOneWidget);
      expect(find.textContaining('Delivered, in review'), findsOneWidget);
      expect(find.text('Delete my account'), findsNothing);
      expect(container.read(authProvider).user, isNotNull);
      await tester.pump(const Duration(seconds: 1)); // the button was replaced while its minimum spinner time ran
    });

    testWidgets('success sends the password once, closes the sheet and signs the person out', (tester) async {
      final container = await _show(tester, const ClientProfileTab());
      await _openSheet(tester);
      await _typePasswordAndDelete(tester, 'secret');
      expect(_deleteCalls, ['secret']);
      expect(container.read(authProvider).user, isNull);
      expect(find.text('Delete your account?'), findsNothing);
      expect(find.text('Your account has been deleted.'), findsOneWidget, reason: 'the person is told it worked');
      await tester.pump(const Duration(seconds: 4)); // let the toast's timer run out
      await tester.pumpAndSettle();
    });

    testWidgets('Keep my account closes the sheet and changes nothing', (tester) async {
      final container = await _show(tester, const ClientProfileTab());
      await _openSheet(tester);
      await tester.tap(find.text('Keep my account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsNothing);
      expect(_deleteCalls, isEmpty);
      expect(container.read(authProvider).user, isNotNull);
    });
  });

  testWidgets('sign-up points at the privacy policy', (tester) async {
    await _show(tester, const SignUpScreen());
    expect(find.textContaining('Privacy policy', findRichText: true), findsOneWidget);
  });
}
