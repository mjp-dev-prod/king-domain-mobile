import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../root_router.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/pressable.dart';
import 'login_screen.dart';

/// T1 — Sign up (POST /users/signup), as a student (talent) or a client.
/// The account exists and is signed in when this succeeds; RootRouter then
/// shows Verify email, since the address isn't confirmed yet.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _role = 'talent';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) throw const ShownError();
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).signUp(
            email: _email.text.trim(),
            password: _password.text,
            role: _role,
            fullName: _name.text.trim(),
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    // RootRouter sees the signed-in, unverified user and shows Verify email.
    RootRouter.popToRoot(context);
  }

  @override
  Widget build(BuildContext context) {
    final talent = _role == 'talent';
    return AuthLayout(
      eyebrow: talent ? 'Student sign up' : 'Client sign up',
      title: 'Create your account',
      lead: Text(talent ? 'Prove your skills, get hired, and get paid safely.' : 'Post jobs and hire students whose work has been checked.'),
      actions: [
        KdButton(label: 'Create account', busyLabel: 'Creating', onPressed: _create),
        AuthLink(
          lead: 'Already have an account? ',
          action: 'Sign in',
          onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
        ),
      ],
      children: [
        Text('I\'m joining as', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RoleTile(
                icon: Icons.school_outlined,
                label: 'Student',
                sub: 'Find work',
                selected: talent,
                onTap: () => setState(() => _role = 'talent'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoleTile(
                icon: Icons.work_outline_rounded,
                label: 'Client',
                sub: 'Hire talent',
                selected: !talent,
                onTap: () => setState(() => _role = 'client'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KdTextField(
                  controller: _name,
                  label: 'Full name',
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter your full name.' : null,
                ),
                const SizedBox(height: 14),
                KdTextField(
                  controller: _email,
                  label: talent ? 'Student email' : 'Email',
                  hintText: talent ? 'you@university.edu.ng' : 'you@company.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address.' : null,
                ),
                const SizedBox(height: 14),
                KdTextField(
                  controller: _password,
                  label: 'Password',
                  hintText: 'At least 8 characters',
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || v.length < 8 ? 'Password must be at least 8 characters.' : null,
                ),
                const SizedBox(height: 14),
                KdTextField(
                  controller: _confirm,
                  label: 'Confirm password',
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _password.text ? 'Passwords don\'t match.' : null,
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'Couldn\'t create your account', body: _error),
        ],
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _RoleTile({required this.icon, required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        semanticLabel: label,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : AppMotion.state,
          curve: AppMotion.ease,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface1,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? AppColors.primaryText : AppColors.text2),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: reduce ? Duration.zero : AppMotion.state,
                    child: const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(label, style: AppTextStyles.title.copyWith(color: selected ? AppColors.text : AppColors.text2)),
              Text(sub, style: AppTextStyles.hint),
            ],
          ),
        ),
      ),
    );
  }
}
