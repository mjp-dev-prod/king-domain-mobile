import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/onboarding/welcome_screen.dart';
import 'presentation/screens/profile/profile_builder_screen.dart';
import 'presentation/screens/shell/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: KingDomainApp()));
}

class KingDomainApp extends StatelessWidget {
  const KingDomainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'King Domain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _RootRouter(),
    );
  }
}

/// Restores a signed-in session on cold start (AuthNotifier._restoreSession)
/// so a returning verified user lands straight in AppShell instead of
/// re-running WelcomeScreen -> LoginScreen every launch.
class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.user == null) {
      return const WelcomeScreen();
    }
    // Same heuristic as login_screen.dart: the backend has no separate
    // "onboarding complete" flag, so emailVerified stands in for it.
    return auth.user!.emailVerified ? const AppShell() : const ProfileBuilderScreen();
  }
}
