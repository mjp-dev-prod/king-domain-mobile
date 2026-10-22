import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../contracts/contract_detail_screen.dart';
import '../jobs/job_detail_screen.dart';
import 'applied_jobs.dart';

/// Talent's "Work" tab. Two segments: **Awarded** (every job awarded to them,
/// with what happens next) and **Applied** (applications still waiting, or not
/// picked). Was labelled "Applications" while listing contracts; the audit's
/// defect 3.
class WorkTab extends ConsumerStatefulWidget {
  final VoidCallback onBrowseJobs;
  const WorkTab({super.key, required this.onBrowseJobs});

  /// Jobs awarded to this talent. Every job in the feed carries its contract,
  /// so the talent's own 'selected' application is what scopes it to them.
  static List<Job> mine(List<Job> jobs) =>
      jobs.where((j) => j.contractStatus != null && j.applicationStatus == JobApplicationStatus.accepted).toList();

  @override
  ConsumerState<WorkTab> createState() => _WorkTabState();
}

class _WorkTabState extends ConsumerState<WorkTab> {
  bool _applied = false;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);
    final all = jobsAsync.valueOrNull ?? const <Job>[];
    final work = WorkTab.mine(all);
    final applied = appliedJobs(all);
    // Needing you first, then active, then finished.
    work.sort((a, b) => contractSortRank(a, forClient: false) - contractSortRank(b, forClient: false));

    final Widget body;
    if (jobsAsync.isLoading && !jobsAsync.hasValue) {
      body = const Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard()]);
    } else if (jobsAsync.hasError && !jobsAsync.hasValue) {
      body = ErrorState(message: 'Couldn\'t load your work. Check your connection and try again.', onRetry: () => ref.read(jobsProvider.notifier).refresh());
    } else if (!_applied) {
      body = work.isEmpty
          ? EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No work yet',
              body: 'When a client picks you for a job, it shows up here with its delivery date and payment status.',
              actionLabel: 'Browse jobs',
              onAction: widget.onBrowseJobs,
            )
          : Column(
              children: [
                for (var i = 0; i < work.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RiseIn(
                      key: ValueKey(work[i].id),
                      delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                      child: ContractTile(
                        job: work[i],
                        forClient: false,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContractDetailScreen(jobId: work[i].id))),
                      ),
                    ),
                  ),
              ],
            );
    } else if (applied.isEmpty) {
      body = EmptyState(
        icon: Icons.outbox_outlined,
        title: 'No applications yet',
        body: 'Apply to a job you\'re verified for and it shows up here until the client picks someone.',
        actionLabel: 'Browse jobs',
        onAction: widget.onBrowseJobs,
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < applied.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RiseIn(
                key: ValueKey('applied-${applied[i].id}'),
                delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                child: AppliedTile(
                  job: applied[i],
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: applied[i].id))),
                ),
              ),
            ),
        ],
      );
    }

    final needs = work.where((j) => contractNeedsYou(j, forClient: false)).length;
    return RefreshIndicator(
      onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 8, AppDimensions.gutter, 120),
        children: [
          ScreenHeader(over: needs > 0 ? '$needs need${needs == 1 ? 's' : ''} you' : null, title: 'Your work'),
          const SizedBox(height: 12),
          // A Wrap, not a Row: large system text or a narrow phone moves the second
          // chip down instead of overflowing.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              KdChoiceChip(label: 'Awarded · ${work.length}', selected: !_applied, onTap: () => setState(() => _applied = false)),
              KdChoiceChip(label: 'Applied · ${applied.length}', selected: _applied, onTap: () => setState(() => _applied = true)),
            ],
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

/// A contract in a list: title, who, money, status, and the next step.
class ContractTile extends StatelessWidget {
  final Job job;
  final bool forClient;
  final VoidCallback onTap;
  final String? who;
  const ContractTile({super.key, required this.job, required this.forClient, required this.onTap, this.who});

  @override
  Widget build(BuildContext context) {
    final next = contractNextStep(job, forClient: forClient);
    final nextColor = next.tone == KdTone.plain ? AppColors.text2 : toneInk(next.tone);
    return KdCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(job.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, height: 1.3))),
              const SizedBox(width: 10),
              contractStatusPill(job.contractStatus!),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(who ?? job.clientName, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis)),
              Text(formatNaira(job.budget), style: AppTextStyles.title.copyWith(color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          if (next.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(next.text, style: AppTextStyles.bodySmall.copyWith(color: nextColor, fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
