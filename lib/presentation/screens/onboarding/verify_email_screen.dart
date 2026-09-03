import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/common/arrow_forward_button.dart';
import '../../widgets/common/section_label.dart';
import '../profile/profile_builder_screen.dart';

const _codeLength = 6;

/// Email verification — 6-digit code entry. Static mock: any complete code
/// is accepted and proceeds to Profile Builder.
class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );
  bool _submitting = false;

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

    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _submitting = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ProfileBuilderScreen()),
      (route) => false,
    );
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
              const SizedBox(height: AppDimensions.lg),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodySmall,
                    children: [
                      const TextSpan(text: "Didn't get it? "),
                      TextSpan(
                        text: 'Resend code',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
