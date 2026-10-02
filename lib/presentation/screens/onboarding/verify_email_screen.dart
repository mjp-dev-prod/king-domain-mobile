import 'dart:async';
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
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/pressable.dart';

const _codeLength = 6;

/// Email verification with the 6-digit code (POST /users/verify-email). The
/// account already exists and is signed in; this confirms the address.
/// One real input drawn as six boxes, so paste and one-time-code autofill
/// work; a full code submits itself.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  /// Between sends. The server allows 5 codes per 15 minutes.
  static const _resendWait = 30;

  final _code = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _verifying = false;
  int _wait = _resendWait;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _code.addListener(_changed);
    _startWait();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() => _error = null);
    // A full code submits itself; failures are already shown on screen.
    if (_code.text.length == _codeLength && !_verifying) _verify().catchError((_) {});
  }

  void _startWait() {
    _ticker?.cancel();
    setState(() => _wait = _resendWait);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != _codeLength) throw const ShownError();
    setState(() => _verifying = true);
    try {
      await ref.read(authProvider.notifier).verifyEmail(_code.text);
    } on ApiException catch (e) {
      if (mounted) {
        // Clear first: clearing fires _changed, which resets the error.
        _code.clear();
        setState(() {
          _error = e.message;
          _verifying = false; // re-enable the field before focusing it
        });
        HapticFeedback.heavyImpact();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
      }
      throw const ShownError();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
    if (!mounted) return;
    // RootRouter sees the verified user and shows the app.
    RootRouter.popToRoot(context);
  }

  Future<void> _resend() async {
    try {
      await ref.read(authProvider.notifier).resendCode();
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (!mounted) return;
    _startWait();
    KdToast.show(context, 'A new code is on its way to ${widget.email}.');
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      eyebrow: 'Verify your email',
      title: 'Enter the code',
      lead: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'We sent a 6-digit code to '),
            TextSpan(text: widget.email, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
            const TextSpan(text: '. Check Spam if it isn\'t there.'),
          ],
        ),
      ),
      actions: [
        KdButton(
          label: 'Verify',
          busyLabel: 'Checking',
          onPressed: _code.text.length == _codeLength && !_verifying ? _verify : null,
        ),
        AuthLink(
          lead: 'Wrong email? ',
          action: 'Sign out and start again',
          onTap: () => ref.read(authProvider.notifier).logout(),
        ),
      ],
      children: [
        _CodeBoxes(controller: _code, focus: _focus, error: _error != null, busy: _verifying),
        if (_error != null) ...[
          const SizedBox(height: 14),
          NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'That code didn\'t work', body: _error),
        ],
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: _wait > 0 ? null : () { _resend().catchError((_) {}); },
            child: Text(_wait > 0 ? 'Resend code in ${_wait}s' : 'Resend code'),
          ),
        ),
      ],
    );
  }
}

/// Six boxes over one hidden field. Tapping anywhere focuses the field.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool error;
  final bool busy;
  const _CodeBoxes({required this.controller, required this.focus, required this.error, required this.busy});

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Pressable(
      onTap: () => focus.requestFocus(),
      scale: 1,
      semanticLabel: 'Verification code',
      child: Stack(
        children: [
          // The real input: invisible, but it owns the keyboard, paste and autofill.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 60,
              child: TextField(
                controller: controller,
                focusNode: focus,
                autofocus: true,
                enabled: !busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_codeLength)],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
          IgnorePointer(
            child: ListenableBuilder(
              listenable: focus,
              builder: (context, _) => Row(
                children: [
                  for (var i = 0; i < _codeLength; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: reduce ? Duration.zero : AppMotion.state,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          border: Border.all(
                            width: 1.5,
                            color: error
                                ? AppColors.bad
                                : focus.hasFocus && i == text.length.clamp(0, _codeLength - 1)
                                    ? AppColors.primaryText
                                    : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          i < text.length ? text[i] : '',
                          style: AppTextStyles.h2.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
