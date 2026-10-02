import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_toast.dart';

/// Step 1: ask for a reset code. Pops with `true` once the password has
/// actually been reset (via [ResetPasswordScreen]), so LoginScreen can say so.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) throw const ShownError();
    final email = _email.text.trim();
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).requestPasswordReset(email);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    final reset = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)));
    if (reset == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      eyebrow: 'Forgot password',
      title: 'Reset your password',
      lead: const Text('Enter the email you signed up with and we\'ll send you a 6-digit code.'),
      actions: [KdButton(label: 'Send code', busyLabel: 'Sending', onPressed: _send)],
      children: [
        Form(
          key: _formKey,
          child: KdTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address.' : null,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'Couldn\'t send a code', body: _error),
        ],
      ],
    );
  }
}

/// Step 2: code + new password. Pops with `true` on success.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  // Matches the backend's per-account cooldown between codes.
  static const _resendCooldown = 60;

  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _resending = false;
  String? _error;
  int _secondsUntilResend = _resendCooldown;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _secondsUntilResend = _resendCooldown);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsUntilResend--);
      if (_secondsUntilResend <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).requestPasswordReset(widget.email);
      if (!mounted) return;
      _startCooldown();
      KdToast.show(context, 'A new code is on its way.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) throw const ShownError();
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).resetPassword(email: widget.email, code: _code.text, newPassword: _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      eyebrow: 'Forgot password',
      title: 'Enter your code',
      lead: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'If an account exists for '),
            TextSpan(text: widget.email, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
            const TextSpan(text: ', we\'ve sent a 6-digit code. It expires in 15 minutes. Check Spam too.'),
          ],
        ),
      ),
      actions: [KdButton(label: 'Reset password', busyLabel: 'Resetting', onPressed: _reset)],
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  style: AppTextStyles.h3.copyWith(letterSpacing: 8, fontFeatures: const [FontFeature.tabularFigures()]),
                  decoration: const InputDecoration(labelText: '6-digit code'),
                  validator: (v) => v == null || v.length != 6 ? 'Enter the 6-digit code.' : null,
                ),
                const SizedBox(height: 14),
                KdTextField(
                  controller: _password,
                  label: 'New password',
                  hintText: 'At least 8 characters',
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => v == null || v.length < 8 ? 'Use at least 8 characters.' : null,
                ),
                const SizedBox(height: 14),
                KdTextField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  isPassword: true,
                  validator: (v) => v != _password.text ? 'Passwords don\'t match.' : null,
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'Couldn\'t reset your password', body: _error),
        ],
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _secondsUntilResend > 0 || _resending ? null : _resend,
            child: Text(
              _resending
                  ? 'Sending…'
                  : _secondsUntilResend > 0
                      ? 'Resend code in ${_secondsUntilResend}s'
                      : 'Resend code',
            ),
          ),
        ),
      ],
    );
  }
}
