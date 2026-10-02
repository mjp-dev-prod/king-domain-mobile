import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/skill_categories.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import 'job_detail_screen.dart';

/// T4 — Job feed (prototypes/palette-explorer.html, screen 01). Open jobs,
/// filterable by category. Each card states plainly whether the talent can
/// apply (verified in that category), so the proof gate is visible while
/// browsing, not a surprise on the apply screen.
class JobFeedScreen extends ConsumerStatefulWidget {
  const JobFeedScreen({super.key});

  @override
  ConsumerState<JobFeedScreen> createState() => _JobFeedScreenState();
}

class _JobFeedScreenState extends ConsumerState<JobFeedScreen> {
  /// null = every category.
  String? _category;

  String _greeting() {
    final h = DateTime.now().hour;
    final part = h < 12 ? 'morning' : h < 17 ? 'afternoon' : 'evening';
    final first = (ref.watch(authProvider).user?.fullName ?? '').trim().split(' ').first;
    return first.isEmpty ? 'Good $part' : 'Good $part, $first';
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);
    final profile = ref.watch(talentProfileProvider).valueOrNull;
    // Open jobs, plus any this talent applied to (so they can see how it went).
    final visible = (jobsAsync.valueOrNull ?? const <Job>[])
        .where((j) => j.awardedApplicationId == null || j.applicationStatus != JobApplicationStatus.notApplied)
        .where((j) => _category == null || j.category == _category)
        .toList();

    final Widget body;
    if (jobsAsync.isLoading && !jobsAsync.hasValue) {
      body = const Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]);
    } else if (jobsAsync.hasError && !jobsAsync.hasValue) {
      body = ErrorState(message: 'Couldn\'t load jobs. Check your connection and try again.', onRetry: () => ref.read(jobsProvider.notifier).refresh());
    } else if (visible.isEmpty) {
      body = EmptyState(
        icon: Icons.work_outline_rounded,
        title: _category == null ? 'No open jobs right now' : 'No open jobs in $_category',
        body: 'New jobs appear here as clients post them. Pull down to check again.',
        actionLabel: _category == null ? null : 'Show every category',
        onAction: _category == null ? null : () => setState(() => _category = null),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RiseIn(
                key: ValueKey(visible[i].id),
                delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                child: JobCard(
                  job: visible[i],
                  canApply: profile?.isVerifiedIn(visible[i].category) ?? false,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: visible[i].id))),
                ),
              ),
            ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 8, AppDimensions.gutter, 120),
        children: [
          ScreenHeader(over: _greeting(), title: 'Jobs for you'),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final c in <String?>[null, ...kSkillCategories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c ?? 'All'),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        fontSize: 13,
                        fontWeight: _category == c ? FontWeight.w600 : FontWeight.w500,
                        color: _category == c ? AppColors.primaryText : AppColors.text2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

/// A job in a list. Money in gold (its one job), the apply gate as a plain fact.
class JobCard extends StatelessWidget {
  final Job job;
  final bool canApply;
  final VoidCallback onTap;
  const JobCard({super.key, required this.job, required this.canApply, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final StatusPill fact = switch (job.applicationStatus) {
      JobApplicationStatus.pending => const StatusPill('Applied', tone: KdTone.brand),
      JobApplicationStatus.accepted => const StatusPill('You were selected', tone: KdTone.ok, icon: Icons.check_rounded),
      JobApplicationStatus.rejected => const StatusPill('Not selected'),
      JobApplicationStatus.notApplied =>
        canApply ? const StatusPill('You qualify', tone: KdTone.ok, icon: Icons.verified_outlined) : const StatusPill('Needs verified proof', icon: Icons.lock_outline_rounded),
    };
    return KdCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: StatusPill(job.category, tone: KdTone.brand)),
              const Spacer(),
              Text(formatAgo(job.postedAt), style: AppTextStyles.hint),
            ],
          ),
          const SizedBox(height: 10),
          Text(job.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(job.clientName, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis)),
              fact,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (job.deliveryDays != null)
                      _Meta(icon: Icons.schedule_rounded, text: '${job.deliveryDays} day${job.deliveryDays == 1 ? '' : 's'}'),
                    _Meta(icon: Icons.people_outline_rounded, text: '${job.applicationCount} applied'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatNaira(job.budget),
                style: AppTextStyles.title.copyWith(fontSize: 17, color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 16, color: AppColors.text2), const SizedBox(width: 5), Text(text, style: AppTextStyles.bodySmall)],
  );
}
