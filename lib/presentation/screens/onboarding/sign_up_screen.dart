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
/// (enter the code, land straight in the app). Role picker added for
/// Phase 2 (client app) — the backend has always accepted 'client', this
/// screen just never offered it.
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
  final _confirmPasswordController = TextEditingController();
  String _role = 'talent';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
            role: _role,
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
                SectionLabel(_role == 'talent' ? 'Talent sign up' : 'Client sign up'),
                const SizedBox(height: AppDimensions.sm),
                Text('Create your account', style: AppTextStyles.h1),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  _role == 'talent'
                      ? 'Student status verification comes right after this.'
                      : 'Post jobs and hire verified student talent.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slateDim,
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),
                _RoleOption(
                  icon: Icons.school_outlined,
                  label: 'Student',
                  selected: _role == 'talent',
                  onTap: () => setState(() => _role = 'talent'),
                ),
                const SizedBox(height: AppDimensions.sm),
                _RoleOption(
                  icon: Icons.work_outline,
                  label: 'Client',
                  selected: _role == 'client',
                  onTap: () => setState(() => _role = 'client'),
                ),
                const SizedBox(height: AppDimensions.xl),
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
                  label: _role == 'talent' ? 'Student email' : 'Email',
                  hintText: _role == 'talent' ? 'you@university.edu' : 'you@company.com',
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
                const SizedBox(height: AppDimensions.lg),
                KingTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  hintText: 'Re-enter your password',
                  isPassword: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords don\'t match.';
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

/// Vertical bordered row, icon avatar + eyebrow/label stack — matches the
/// rentipede project's SignupRolePage/SelectableOption pattern (full-width
/// stacked rows, not side-by-side cards), restyled to King Domain's own
/// dark ink/gold tokens instead of rentipede's teal.
class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.1) : AppColors.ink2,
          border: Border.all(color: selected ? AppColors.gold : AppColors.ink3),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold.withValues(alpha: 0.18) : AppColors.ink3,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppDimensions.iconSm,
                color: selected ? AppColors.gold : AppColors.slateDim,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign up as',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateDim),
                  ),
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: selected ? AppColors.gold : AppColors.paper,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: AppDimensions.iconSm, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
