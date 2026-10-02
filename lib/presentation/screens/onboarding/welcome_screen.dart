import 'package:flutter/material.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/motion.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

/// The first screen a new user sees. The moment comes from type and the
/// three promises the product actually makes, not from decoration.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return Scaffold(
      body: SafeArea(
        // Scrolls only when it must (short phones, large system text).
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 16, AppDimensions.gutter, 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 28),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
                          child: Text(AppBrand.mark, style: AppTextStyles.logomark.copyWith(fontSize: 18)),
                        ),
                        const SizedBox(width: 10),
                        Text(AppBrand.name, style: AppTextStyles.title),
                      ],
                    ),
                    const Spacer(flex: 2),
                    RiseIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STUDENT TALENT MARKETPLACE', style: AppTextStyles.label),
                          const SizedBox(height: 10),
                          Text.rich(
                            TextSpan(
                              style: AppTextStyles.h1.copyWith(fontSize: 42, height: 1.05, letterSpacing: -1.4),
                              children: const [
                                TextSpan(text: 'Prove it.\n'),
                                TextSpan(
                                  text: 'Get hired.',
                                  style: TextStyle(color: AppColors.primaryText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const RiseIn(
                      delay: Duration(milliseconds: 80),
                      child: _Promise(icon: Icons.verified_outlined, text: 'A person checks your work before you apply, so clients trust it.'),
                    ),
                    const RiseIn(
                      delay: Duration(milliseconds: 140),
                      child: _Promise(icon: Icons.lock_outline_rounded, text: 'Clients pay up front. The money is held until the work is approved.'),
                    ),
                    const RiseIn(
                      delay: Duration(milliseconds: 200),
                      child: _Promise(icon: Icons.workspace_premium_outlined, text: 'Every finished job builds a record that outlasts graduation.'),
                    ),
                    const Spacer(flex: 3),
                    KdButton(label: 'Create account', onPressed: () => open(const SignUpScreen())),
                    const SizedBox(height: 10),
                    KdButton.secondary(label: 'I already have an account', onPressed: () => open(const LoginScreen())),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Promise({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.primaryText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)),
          ),
        ),
      ],
    ),
  );
}
