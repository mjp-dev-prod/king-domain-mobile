import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_brand.dart';
import 'core/theme/app_theme.dart';
import 'data/api_client.dart';
import 'presentation/root_router.dart';
import 'presentation/widgets/common/environment_banner.dart';

void main() {
  runApp(const ProviderScope(child: KingDomainApp()));
}

class KingDomainApp extends StatelessWidget {
  const KingDomainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (context, child) => EnvironmentBanner(host: nonProductionApiHost, child: child!),
      // Restores a signed-in session on cold start (AuthNotifier._restoreSession),
      // so a returning verified user lands straight in the app.
      home: const RootRouter(),
    );
  }
}
