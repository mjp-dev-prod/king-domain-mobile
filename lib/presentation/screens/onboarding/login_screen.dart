import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../root_router.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_toast.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// Returning-user path (POST /users/login).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) throw const ShownError();
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).login(email: _email.text.trim(), password: _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    // RootRouter now shows the app, or Verify email if it isn't verified
    // yet. Never push the app from here: it must sit on RootRouter, or
    // signing out later leaves the user stranded inside it.
    RootRouter.popToRoot(context);
  }

  Future<void> _forgotPassword() async {
    final reset = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim())),
    );
    if (reset != true || !mounted) return;
    _password.clear();
    setState(() => _error = null);
    KdToast.show(context, 'Password reset. Sign in with your new password.');
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      eyebrow: 'Welcome back',
      title: 'Sign in to your account',
      actions: [
        KdButton(label: 'Sign in', busyLabel: 'Signing in', onPressed: _signIn),
        AuthLink(
          lead: 'Don\'t have an account? ',
          action: 'Sign up',
          onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SignUpScreen())),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KdTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address.' : null,
                ),
                const SizedBox(height: 14),
                KdTextField(
                  controller: _password,
                  label: 'Password',
                  isPassword: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  validator: (v) => v == null || v.isEmpty ? 'Enter your password.' : null,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'Couldn\'t sign in', body: _error),
        ],
      ],
    );
  }
}
