import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/common/section_label.dart';
import 'apply_screen.dart';

/// T5 — Job Detail. Full spec, plus the client's verified profile/rating —
/// the symmetric trust signal from C1.5 shown here on the talent side.
class JobDetailScreen extends ConsumerWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobsProvider).firstWhere((j) => j.id == jobId);
    final profile = ref.watch(talentProfileProvider);
    final isVerified = profile.isVerifiedIn(job.category);
    final alreadyApplied = job.applicationStatus != JobApplicationStatus.notApplied;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          children: [
            SectionLabel(job.category),
            const SizedBox(height: AppDimensions.sm),
            Text(job.title, style: AppTextStyles.h2),
            const SizedBox(height: AppDimensions.md),
            Text(
              '\$${job.budget.toStringAsFixed(0)}',
              style: AppTextStyles.h3.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text('Description', style: AppTextStyles.h3),
            const SizedBox(height: AppDimensions.sm),
            Text(job.description, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimensions.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.ink3,
                      child: Text(
                        job.clientName.isNotEmpty
                            ? job.clientName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.h3,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                job.clientName,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              Icon(Icons.verified, size: 14, color: AppColors.settled),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${job.clientRating} rating · '
                            '${job.clientCompletedJobs} jobs completed',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.xxl),
            if (!isVerified) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.openPending.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.openPending.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: AppDimensions.iconSm, color: AppColors.openPending),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'You need Verified status in ${job.category} to apply. '
                        'Submit proof from your profile first.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
            ],
            ElevatedButton(
              onPressed: (!isVerified || alreadyApplied)
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ApplyScreen(jobId: job.id)),
                    ),
              child: Text(
                alreadyApplied
                    ? 'Already applied'
                    : (isVerified ? 'Apply for this job' : 'Verification required'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
