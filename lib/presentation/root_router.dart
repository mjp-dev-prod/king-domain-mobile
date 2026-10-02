import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/onboarding/verify_email_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/shell/app_shell.dart';
import 'widgets/kit/motion.dart';

/// The one place that decides which top-level screen a user sees, from the
/// auth state: Welcome, Verify email, or the app. It must stay the bottom
/// route forever. Screens that finish signing in or verifying pop back down
/// to it ([popToRoot]) instead of pushing the app themselves; pushing over or
/// replacing this route is what left signed-out users stuck on Profile as
/// "Unnamed" (docs/research/ui-audit-2026-10-01.md, defect 1).
class RootRouter extends ConsumerWidget {
  const RootRouter({super.key});

  /// After a sign-in or verification: drop the onboarding screens and let
  /// RootRouter show whatever the new auth state calls for.
  static void popToRoot(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    final Widget screen;
    if (auth.loading) {
      screen = const Scaffold(key: ValueKey('loading'), body: Center(child: Skeleton(height: 24, width: 120)));
    } else if (auth.user == null) {
      screen = const WelcomeScreen(key: ValueKey('welcome'));
    } else if (!auth.user!.emailVerified) {
      screen = VerifyEmailScreen(key: const ValueKey('verify'), email: auth.user!.email);
    } else {
      // Profile/proof-upload is an in-app task (Profile tab), not a gate
      // before entry: every verified user of either role goes straight in.
      screen = const AppShell(key: ValueKey('app'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: screen);
  }
}
