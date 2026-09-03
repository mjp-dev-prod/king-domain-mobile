import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/common/section_label.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

/// Real entry point — the first screen a new user sees. Composition is the
/// "designed" moment brand v0 asks for (bold Fraunces + gold italic, precise
/// spacing) rather than a graphic effect, since gradients/illustrations are
/// off the table.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.xl,
            AppDimensions.lg,
            AppDimensions.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Student talent marketplace'),
              const Spacer(flex: 2),
              Text.rich(
                TextSpan(
                  style: AppTextStyles.h1.copyWith(fontSize: 44, height: 1.05),
                  children: [
                    const TextSpan(text: 'Prove it.\n'),
                    TextSpan(
                      text: 'Get hired.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'Work under protected payment terms and build a reputation '
                'that outlasts graduation.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.slateDim,
                ),
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
                child: const Text('Create account'),
              ),
              const SizedBox(height: AppDimensions.md),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
