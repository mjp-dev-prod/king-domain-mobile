import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/onboarding/welcome_screen.dart';

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
      home: const WelcomeScreen(),
    );
  }
}
