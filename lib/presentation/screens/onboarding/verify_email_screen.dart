import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/arrow_forward_button.dart';
import '../../widgets/common/section_label.dart';
import '../profile/profile_builder_screen.dart';

const _codeLength = 6;

/// Email verification — real 6-digit OTP now (king-domain-backend's
/// /users/verify-email + /users/resend-code — Sprint 4). The account
/// already exists and is signed in by the time this screen is reached
/// (see SignUpScreen); this confirms email ownership, it doesn't gate
/// signing in.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );
  bool _submitting = false;
  bool _resending = false;
  String? _error;

  bool get _isComplete =>
      _controllers.every((c) => c.text.trim().isNotEmpty);

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    if (!_isComplete) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final code = _controllers.map((c) => c.text.trim()).join();

    try {
      await ref.read(authProvider.notifier).verifyEmail(code);
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfileBuilderScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).resendCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code is on its way.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.sm,
            AppDimensions.lg,
            AppDimensions.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Verify your email'),
              const SizedBox(height: AppDimensions.sm),
              Text('Enter the code', style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.sm),
              Text.rich(
                TextSpan(
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.slateDim,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: AppColors.paper,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_codeLength, (index) {
                  return SizedBox(
                    width: 44,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: AppTextStyles.h3,
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppDimensions.md),
                Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              Center(
                child: GestureDetector(
                  onTap: _resending ? null : _resend,
                  child: Text.rich(
                    TextSpan(
                      style: AppTextStyles.bodySmall,
                      children: [
                        const TextSpan(text: "Didn't get it? "),
                        TextSpan(
                          text: _resending ? 'Sending…' : 'Resend code',
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
              const Spacer(),
              ArrowForwardButton(
                onPressed: _isComplete && !_submitting ? _verify : null,
                loading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
