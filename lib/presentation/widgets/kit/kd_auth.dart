import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../contract/contract_parts.dart';
import 'pressable.dart';

/// The shared layout for sign-up, sign-in, verification and password reset:
/// a back button when there is somewhere to go back to, a mono eyebrow, the
/// title, a lead line, the form, and the main action in a sticky bar that
/// rides above the keyboard. One layout keeps the whole flow reading as one.
class AuthLayout extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? lead;
  final List<Widget> children;
  final List<Widget> actions;

  const AuthLayout({super.key, required this.eyebrow, required this.title, this.lead, required this.children, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: canPop
                        ? Pressable(
                            onTap: () => Navigator.of(context).maybePop(),
                            semanticLabel: 'Back',
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Text(eyebrow.toUpperCase(), style: AppTextStyles.label),
                const SizedBox(height: 6),
                Text(title, style: AppTextStyles.h1),
                if (lead != null) ...[
                  const SizedBox(height: 8),
                  DefaultTextStyle.merge(style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2), child: lead!),
                ],
                const SizedBox(height: 28),
                ...children,
              ],
            ),
          ),
          if (actions.isNotEmpty) Positioned(left: 0, right: 0, bottom: 0, child: ActionBar(children: actions)),
        ],
      ),
    );
  }
}

/// Form text field for the auth flow and anywhere a validated field is
/// needed: label above the value, optional show/hide for passwords.
class KdTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const KdTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<KdTextField> createState() => _KdTextFieldState();
}

class _KdTextFieldState extends State<KdTextField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autocorrect: !widget.isPassword && widget.keyboardType != TextInputType.emailAddress,
      style: AppTextStyles.bodyMedium,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.text3, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }
}

/// A tappable line of text ("Don't have an account? Sign up").
class AuthLink extends StatelessWidget {
  final String lead;
  final String action;
  final VoidCallback? onTap;
  const AuthLink({super.key, required this.lead, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text.rich(
          TextSpan(
            style: AppTextStyles.bodySmall,
            children: [
              TextSpan(text: lead),
              TextSpan(text: action, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText, fontWeight: FontWeight.w700)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
