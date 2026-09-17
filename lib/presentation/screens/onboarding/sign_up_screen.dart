import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/arrow_forward_button.dart';
import '../../widgets/common/king_text_field.dart';
import '../../widgets/common/section_label.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

/// T1 — Sign Up. Identity + student status verification entry point (see
/// Milestone 02 screen map). Real backend now (king-domain-backend's
/// /users/signup — Sprint 1/4): the account exists and is already signed
/// in by the time VerifyEmailScreen opens, matching that screen's own UX
/// (enter the code, land straight in the app).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: 'talent',
            fullName: _fullNameController.text.trim(),
          );
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: _emailController.text.trim()),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
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
                const SectionLabel('Talent sign up'),
                const SizedBox(height: AppDimensions.sm),
                Text('Create your account', style: AppTextStyles.h1),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'Student status verification comes right after this.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slateDim,
                  ),
                ),
                const SizedBox(height: AppDimensions.xxl),
                KingTextField(
                  controller: _fullNameController,
                  label: 'Full name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your full name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.lg),
                KingTextField(
                  controller: _emailController,
                  label: 'Student email',
                  hintText: 'you@university.edu',
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
                  hintText: 'At least 8 characters',
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Password must be at least 8 characters.';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                  ),
                ],
                const SizedBox(height: AppDimensions.xxl),
                ArrowForwardButton(
                  onPressed: _submitting ? null : _continue,
                  loading: _submitting,
                ),
                const SizedBox(height: AppDimensions.lg),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: AppTextStyles.bodySmall,
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
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
