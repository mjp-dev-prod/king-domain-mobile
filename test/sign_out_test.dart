// Regression: after signing in through Welcome -> Login, signing out used to
// leave the user on the Profile tab as "Unnamed", because Login pushed the app
// over RootRouter (and Verify email replaced RootRouter entirely), so nothing
// reacted to the signed-out state. docs/research/ui-audit-2026-10-01.md.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/root_router.dart';
import 'package:king_domain/presentation/screens/shell/app_shell.dart';
import 'package:king_domain/presentation/screens/onboarding/welcome_screen.dart';
import 'package:king_domain/presentation/widgets/common/arrow_forward_button.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(loading: false);

  @override
  Future<void> login({required String email, required String password}) async {
    state = const AuthState(
      loading: false,
      user: AuthUser(id: 'u1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true),
    );
  }

  @override
  Future<void> logout() async => state = const AuthState(loading: false);
}

class _Jobs extends JobsNotifier {
  @override
  Future<List<Job>> build() async => const [];
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile();
}

void main() {
  testWidgets('sign in from Welcome, then sign out: back on Welcome, not stranded in the app', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final auth = _Auth();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(() => auth),
        jobsProvider.overrideWith(_Jobs.new),
        talentProfileProvider.overrideWith(_Profile.new),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const RootRouter(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'ada@uni.edu.ng');
    await tester.enterText(find.byType(TextFormField).at(1), 'correct horse battery');
    await tester.tap(find.descendant(of: find.byType(ArrowForwardButton), matching: find.byIcon(Icons.arrow_forward)));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget, reason: 'signed in');
    expect(find.byType(WelcomeScreen), findsNothing);

    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsNothing, reason: 'no app left on screen after signing out');
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
