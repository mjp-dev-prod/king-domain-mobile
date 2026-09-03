import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'section_label.dart';

/// Shared header for the T1-T3 onboarding flow: step counter, title, and a
/// thin progress bar so the whole sequence reads as one continuous flow.
class OnboardingStepHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;

  const OnboardingStepHeader({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Step $step of $totalSteps'),
        const SizedBox(height: AppDimensions.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: LinearProgressIndicator(
            value: step / totalSteps,
            minHeight: 3,
            backgroundColor: AppColors.ink3,
            valueColor: const AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        Text(title, style: AppTextStyles.h2),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimensions.sm),
          Text(
            subtitle!,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
          ),
        ],
      ],
    );
  }
}
