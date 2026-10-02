import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_button.dart';
import 'kd_card.dart';
import 'pressable.dart';

/// A tab's header: a small line above (greeting, count) and the title, with
/// an optional action on the right.
class ScreenHeader extends StatelessWidget {
  final String? over;
  final String title;
  final Widget? trailing;
  const ScreenHeader({super.key, this.over, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (over != null) Text(over!, style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
                Text(title, style: AppTextStyles.h1),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A section title inside a screen, with an optional text action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.title)),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(action!, style: AppTextStyles.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty states answer three things (brand v1): why it's empty, what to do
/// next, and what will appear here.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
            child: Icon(icon, size: 28, color: AppColors.primaryText),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(fontSize: 13.5)),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            SizedBox(width: 220, child: KdButton(label: actionLabel!, variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: onAction)),
          ],
        ],
      ),
    );
  }
}

/// Couldn't load: says so plainly and offers Retry.
class ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 30, color: AppColors.text3),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)),
          const SizedBox(height: 16),
          SizedBox(width: 160, child: KdButton.secondary(label: 'Try again', busyLabel: 'Loading', height: AppDimensions.buttonHeightSm, onPressed: onRetry)),
        ],
      ),
    );
  }
}

/// One row in a grouped list: icon tile, title, sub line, chevron.
class ListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final KdTone subTone;
  final bool danger;
  final VoidCallback? onTap;
  const ListRow({super.key, required this.icon, required this.title, this.sub, this.subTone = KdTone.plain, this.danger = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = danger ? AppColors.bad : AppColors.text;
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: danger ? AppColors.badSoft : AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
              child: Icon(icon, size: 20, color: danger ? AppColors.bad : AppColors.text2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: ink)),
                  if (sub != null)
                    Text(sub!, style: AppTextStyles.bodySmall.copyWith(color: subTone == KdTone.plain ? AppColors.text2 : toneInk(subTone))),
                ],
              ),
            ),
            if (!danger) const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
          ],
        ),
      ),
    );
  }
}

/// Rows grouped on one card with hairline dividers between them.
class ListGroup extends StatelessWidget {
  final List<Widget> rows;
  const ListGroup({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(indent: 64),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// Initials in a circle, with an optional ring showing progress (e.g. profile
/// completion). Real photos replace this once profile photos exist
/// (docs/features/imagery-surfaces.md, surface 2).
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double? ring; // 0..1
  const InitialsAvatar({super.key, required this.name, this.size = 44, this.ring});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.surface3, shape: BoxShape.circle),
      child: Text(_initials, style: AppTextStyles.title.copyWith(fontSize: size * .36)),
    );
    if (ring == null) return face;
    return SizedBox(
      width: size + 12,
      height: size + 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size + 12,
            height: size + 12,
            child: CircularProgressIndicator(value: ring, strokeWidth: 4, color: AppColors.primary, backgroundColor: AppColors.surface3),
          ),
          face,
        ],
      ),
    );
  }
}
