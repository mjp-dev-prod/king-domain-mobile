import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import 'pressable.dart';

/// What a card is telling you. Tinted tones keep their colour's one job:
/// [ok] verified/done, [warn] waiting on someone, [bad] error or missed,
/// [brand] something you can act on.
enum KdTone { plain, ok, warn, bad, brand }

Color toneSurface(KdTone tone) => switch (tone) {
  KdTone.plain => AppColors.surface1,
  KdTone.ok => AppColors.okSoft,
  KdTone.warn => AppColors.warnSoft,
  KdTone.bad => AppColors.badSoft,
  KdTone.brand => AppColors.primarySoft,
};

Color toneInk(KdTone tone) => switch (tone) {
  KdTone.plain => AppColors.text2,
  KdTone.ok => AppColors.ok,
  KdTone.warn => AppColors.warn,
  KdTone.bad => AppColors.bad,
  KdTone.brand => AppColors.primaryText,
};

/// A card is one surface step above what it sits on: no outline, no shadow
/// (brand v1 tonal depth). [hero] cards get the larger radius.
class KdCard extends StatelessWidget {
  final Widget child;
  final KdTone tone;
  final bool hero;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const KdCard({
    super.key,
    required this.child,
    this.tone = KdTone.plain,
    this.hero = false,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final card = AnimatedContainer(
      duration: reduce ? Duration.zero : AppMotion.layout,
      curve: AppMotion.ease,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: toneSurface(tone),
        borderRadius: BorderRadius.circular(hero ? AppDimensions.radiusXl : AppDimensions.radiusLg),
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: .985, child: card);
  }
}
