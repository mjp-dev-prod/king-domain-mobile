import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/common/arrow_forward_button.dart';
import '../../widgets/common/king_text_field.dart';
import '../../widgets/common/section_label.dart';
import '../profile/profile_builder_screen.dart';
import 'sign_up_screen.dart';

/// Returning-user path. Static mock — logging in with any valid-looking
/// credentials proceeds straight to the app, since there's no real backend
/// wired yet.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _submitting = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileBuilderScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.sm,
            AppDimensions.lg,
            AppDimensions.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Welcome back'),
                const SizedBox(height: AppDimensions.sm),
                Text('Sign in', style: AppTextStyles.h1),
                const SizedBox(height: AppDimensions.xxl),
                KingTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.lg),
                KingTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Enter your password',
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter your password.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Forgot password?',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.gold),
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),
                ArrowForwardButton(
                  onPressed: _submitting ? null : _continue,
                  loading: _submitting,
                ),
                const SizedBox(height: AppDimensions.lg),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: AppTextStyles.bodySmall,
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Sign up',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
