import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/arrow_forward_button.dart';
import '../../widgets/common/king_text_field.dart';
import '../../widgets/common/section_label.dart';

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
  late final _emailController = TextEditingController(text: widget.initialEmail);
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).requestPasswordReset(email);
      if (!mounted) return;
      final reset = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
      );
      if (!mounted) return;
      if (reset == true) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppDimensions.lg, AppDimensions.sm, AppDimensions.lg, AppDimensions.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Forgot password'),
                const SizedBox(height: AppDimensions.sm),
                Text('Reset your password', style: AppTextStyles.h1),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'Enter the email you signed up with and we\'ll send you a 6-digit code.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
                ),
                const SizedBox(height: AppDimensions.xxl),
                KingTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value == null || !value.contains('@') ? 'Enter a valid email address.' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending)),
                ],
                const SizedBox(height: AppDimensions.xl),
                ArrowForwardButton(onPressed: _submitting ? null : _send, loading: _submitting),
              ],
            ),
          ),
        ),
      ),
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
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
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
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code is on its way.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).resetPassword(
            email: widget.email,
            code: _codeController.text,
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppDimensions.lg, AppDimensions.sm, AppDimensions.lg, AppDimensions.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Forgot password'),
                const SizedBox(height: AppDimensions.sm),
                Text('Enter your code', style: AppTextStyles.h1),
                const SizedBox(height: AppDimensions.sm),
                Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
                    children: [
                      const TextSpan(text: 'If an account exists for '),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(color: AppColors.paper, fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ', we\'ve sent a 6-digit code. It expires in 15 minutes — check Spam too.'),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.xxl),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  style: AppTextStyles.h3.copyWith(letterSpacing: 8),
                  decoration: const InputDecoration(labelText: '6-digit code'),
                  validator: (value) => value == null || value.length != 6 ? 'Enter the 6-digit code.' : null,
                ),
                const SizedBox(height: AppDimensions.lg),
                KingTextField(
                  controller: _passwordController,
                  label: 'New password',
                  hintText: 'At least 8 characters',
                  isPassword: true,
                  validator: (value) =>
                      value == null || value.length < 8 ? 'Use at least 8 characters.' : null,
                ),
                const SizedBox(height: AppDimensions.lg),
                KingTextField(
                  controller: _confirmController,
                  label: 'Confirm new password',
                  isPassword: true,
                  validator: (value) => value != _passwordController.text ? 'Passwords don\'t match.' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending)),
                ],
                const SizedBox(height: AppDimensions.lg),
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
                const SizedBox(height: AppDimensions.md),
                ElevatedButton(
                  onPressed: _submitting ? null : _reset,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2.5),
                        )
                      : const Text('Reset password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
