import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/common/section_label.dart';
import 'job_detail_screen.dart';

/// T4 — Job Feed. Browse open jobs. Each row shows whether the talent is
/// verified in that job's category, so the gating story from Milestone 03
/// is visible while browsing, not just a surprise on the apply screen.
class JobFeedScreen extends ConsumerWidget {
  const JobFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider);
    final profile = ref.watch(talentProfileProvider);

    if (jobs.isEmpty) {
      return Center(
        child: Text('No open jobs right now.', style: AppTextStyles.bodyMedium),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      children: [
        const SectionLabel('Open jobs'),
        const SizedBox(height: AppDimensions.md),
        for (final job in jobs) ...[
          _JobCard(
            job: job,
            isVerified: profile.isVerifiedIn(job.category),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
        ],
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final bool isVerified;
  final VoidCallback onTap;

  const _JobCard({required this.job, required this.isVerified, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.category,
                      style: AppTextStyles.label.copyWith(color: AppColors.gold),
                    ),
                  ),
                  if (!isVerified)
                    Icon(Icons.lock_outline, size: 14, color: AppColors.slateDim),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                job.title,
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Text(
                    '\$${job.budget.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Text('·', style: AppTextStyles.bodySmall),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      job.clientName,
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
