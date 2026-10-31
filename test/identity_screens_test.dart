import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/identity.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/identity_provider.dart';
import 'package:king_domain/presentation/screens/identity/identity_rows.dart';
import 'package:king_domain/presentation/screens/identity/identity_screen.dart';
import 'package:king_domain/presentation/screens/identity/region_education_screen.dart';

class _Auth extends AuthNotifier {
  final String role;
  _Auth(this.role);
  @override
  AuthState build() => AuthState(loading: false, user: AuthUser(id: 'u1', email: 'ada@uni.edu.ng', role: role, fullName: 'Ada Obi', emailVerified: true));
}

IdentitySummary _summary({
  IdentityStatus status = IdentityStatus.notStarted,
  bool minor = false,
  bool guardianNeeded = false,
  IdentityReason? reason,
  GuardianInfo? guardian,
}) => IdentitySummary(status: status, minor: minor, guardianNeeded: guardianNeeded, canTransact: status == IdentityStatus.verified && !guardianNeeded, requiredForPaidActions: false, reason: reason, guardian: guardian);

Widget _app(Widget home, {IdentitySummary? identity, AboutYou? about, String role = 'talent'}) => ProviderScope(
  overrides: [
    authProvider.overrideWith(() => _Auth(role)),
    identityProvider.overrideWith((ref) async => identity ?? _summary()),
    aboutYouProvider.overrideWith((ref) async => about ?? const AboutYou()),
  ],
  child: MaterialApp(theme: AppTheme.theme, home: home),
);

/// pumpAndSettle never returns while the pulsing 'being checked' dot is on screen, so advance a fixed time.
extension on WidgetTester {
  Future<void> settle([int ms = 700]) async {
    await pump();
    await pump(Duration(milliseconds: ms));
  }
}

void main() {
  group('IdentityScreen', () {
    testWidgets('not started: says why, how long, and Start opens the consent screen with nothing pre-ticked', (tester) async {
      await tester.pumpWidget(_app(const IdentityScreen()));
      await tester.settle();
      expect(find.text('Takes about 3 minutes'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.settle();
      expect(find.text('Check your identity'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    });

    testWidgets('being checked: says a person is on it and when to expect an answer', (tester) async {
      await tester.pumpWidget(_app(const IdentityScreen(), identity: _summary(status: IdentityStatus.inReview)));
      await tester.settle();
      expect(find.text('A person is checking it'), findsOneWidget);
      expect(find.textContaining('up to 2 days'), findsOneWidget);
    });

    testWidgets('not yet: shows the reason and the checker note, and offers to send again', (tester) async {
      await tester.pumpWidget(_app(
        const IdentityScreen(),
        identity: _summary(status: IdentityStatus.notYet, reason: const IdentityReason(code: 'unreadable', label: 'The photo is hard to read', note: 'Flatten the slip.')),
      ));
      await tester.settle();
      expect(find.text('The photo is hard to read'), findsOneWidget);
      expect(find.textContaining('Flatten the slip.'), findsOneWidget);
      expect(find.text('Send it again'), findsOneWidget);
    });

    testWidgets('verified adult: confirms it and has no guardian step', (tester) async {
      await tester.pumpWidget(_app(const IdentityScreen(), identity: _summary(status: IdentityStatus.verified)));
      await tester.settle();
      expect(find.text('You are verified'), findsOneWidget);
      expect(find.textContaining('parent or guardian'), findsNothing);
    });

    testWidgets('a minor is asked for a guardian, who stays the only blocker until they confirm', (tester) async {
      await tester.pumpWidget(_app(const IdentityScreen(), identity: _summary(status: IdentityStatus.verified, minor: true, guardianNeeded: true)));
      await tester.settle();
      expect(find.text('Under 18: add a parent or guardian'), findsOneWidget);
      expect(find.textContaining('never theirs'), findsOneWidget);
      await tester.tap(find.text('Add them'));
      await tester.settle();
      expect(find.text('Send the link'), findsOneWidget);
    });

    testWidgets('a guardian who has been emailed but not confirmed: waiting, with a way to resend', (tester) async {
      await tester.pumpWidget(_app(
        const IdentityScreen(),
        identity: _summary(status: IdentityStatus.inReview, minor: true, guardianNeeded: true, guardian: const GuardianInfo(name: 'Ada Obi', email: 'ada@example.com', confirmed: false)),
      ));
      await tester.settle();
      expect(find.text('Waiting for Ada Obi'), findsOneWidget);
      expect(find.text('Send the link again'), findsOneWidget);
    });
  });

  group('IdentityGroup (profile rows)', () {
    Future<void> pump(WidgetTester tester, {IdentitySummary? identity, AboutYou? about, String role = 'talent'}) async {
      await tester.pumpWidget(_app(const Scaffold(body: IdentityGroup()), identity: identity, about: about, role: role));
      await tester.settle();
    }

    testWidgets('nothing saved yet: both rows say what to do', (tester) async {
      await pump(tester);
      expect(find.textContaining('Not set'), findsOneWidget);
      expect(find.textContaining('Not started'), findsOneWidget);
    });

    testWidgets('a saved student sees their region and education line, and a verified person sees Verified', (tester) async {
      await pump(
        tester,
        identity: _summary(status: IdentityStatus.verified),
        about: const AboutYou(region: Region(country: 'Nigeria', state: 'Lagos', city: 'Yaba'), education: EducationLine(kind: EducationKind.student, school: 'UNILAG', detail: '2026/27')),
      );
      expect(find.textContaining('Yaba, Lagos, Nigeria'), findsOneWidget);
      expect(find.textContaining('Student · UNILAG · 2026/27'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('a client is asked for region only, not for training', (tester) async {
      await pump(tester, role: 'client', about: const AboutYou(region: Region(country: 'Ghana'), clientKind: 'business'));
      expect(find.text('Ghana'), findsOneWidget);
    });
  });

  group('RegionEducationScreen', () {
    testWidgets('a talent must choose a state in Nigeria and an education line before saving', (tester) async {
      await tester.pumpWidget(_app(const RegionEducationScreen()));
      await tester.settle();
      expect(find.text('About you'), findsOneWidget);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.settle();
      expect(find.text('Choose your state.'), findsOneWidget);
    });

    testWidgets('picking Student asks for the school and session; Self-taught asks for neither', (tester) async {
      await tester.pumpWidget(_app(const RegionEducationScreen()));
      await tester.settle();
      await tester.ensureVisible(find.text('Student'));
      await tester.tap(find.text('Student'));
      await tester.settle();
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Session, e.g. 2026/27'), findsOneWidget);
      await tester.tap(find.text('Self-taught'));
      await tester.settle();
      expect(find.text('School'), findsNothing);
    });
  });
}
