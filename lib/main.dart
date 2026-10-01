import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/api_client.dart';
import 'presentation/widgets/common/environment_banner.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/onboarding/verify_email_screen.dart';
import 'presentation/screens/onboarding/welcome_screen.dart';
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
      builder: (context, child) => EnvironmentBanner(host: nonProductionApiHost, child: child!),
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
    final user = auth.user!;
    if (!user.emailVerified) {
      return VerifyEmailScreen(email: user.email);
    }
    // Profile/proof-upload is an in-app task now (Profile tab), not a gate
    // before entry — every verified user of either role goes straight in.
    return const AppShell();
  }
}
