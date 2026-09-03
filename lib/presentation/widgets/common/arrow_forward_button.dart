import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Circular gold arrow-forward button — the primary CTA shape across the
/// auth/onboarding flow. Flat fill, no glow/shadow (brand v0 bans heavy
/// shadows) — depth comes from the disabled state's dimmed fill only.
class ArrowForwardButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const ArrowForwardButton({super.key, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? AppColors.gold : AppColors.ink3,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.ink,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(
                      Icons.arrow_forward,
                      color: enabled ? AppColors.ink : AppColors.slateDim,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
