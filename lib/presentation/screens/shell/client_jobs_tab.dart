import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import '../client/applicants_screen.dart';
import '../client/client_contract_screen.dart';
import '../client/post_job_flow.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_button.dart';
import '../payments/fund_contract_screen.dart';
import 'work_tab.dart';

/// C0 — My jobs (client): jobs this client posted, filtered from the shared
/// feed by clientId. Open jobs show their applicants; awarded ones open the
/// contract (or payment, while unpaid).
class ClientJobsTab extends ConsumerWidget {
  final VoidCallback onPostJob;
  const ClientJobsTab({super.key, required this.onPostJob});

  static List<Job> mine(List<Job> jobs, String? clientId) => jobs.where((j) => j.clientId == clientId).toList();

  /// Needing you first; open jobs (no contract) rank with the active ones; closed
  /// jobs go last. Stable for equal ranks.
  static List<Job> sorted(List<Job> jobs) {
    int rank(Job j) => j.closed ? 3 : (j.contractStatus == null ? 1 : contractSortRank(j, forClient: true));
    final indexed = [for (var i = 0; i < jobs.length; i++) (i, jobs[i])];
    indexed.sort((a, b) {
      final r = rank(a.$2) - rank(b.$2);
      return r != 0 ? r : a.$1 - b.$1;
    });
    return [for (final e in indexed) e.$2];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    final jobs = sorted(mine(jobsAsync.valueOrNull ?? const [], ref.watch(authProvider).user?.id));

    final Widget body;
    if (jobsAsync.isLoading && !jobsAsync.hasValue) {
      body = const Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard()]);
    } else if (jobsAsync.hasError && !jobsAsync.hasValue) {
      body = ErrorState(message: 'Couldn\'t load your jobs. Check your connection and try again.', onRetry: () => ref.read(jobsProvider.notifier).refresh());
    } else if (jobs.isEmpty) {
      body = EmptyState(
        icon: Icons.add_business_outlined,
        title: 'No jobs posted yet',
        body: 'Post a job and verified students apply. You pay only when you pick someone, and they\'re paid only when you approve the work.',
        actionLabel: 'Post a job',
        onAction: onPostJob,
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < jobs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RiseIn(key: ValueKey(jobs[i].id), delay: Duration(milliseconds: 40 * i.clamp(0, 6)), child: _tile(context, jobs[i])),
            ),
        ],
      );
    }

    final needs = jobs.where((j) => contractNeedsYou(j, forClient: true)).length;
    return RefreshIndicator(
      onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 8, AppDimensions.gutter, 120),
        children: [
          ScreenHeader(over: needs > 0 ? '$needs need${needs == 1 ? 's' : ''} you' : null, title: 'My jobs'),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Job job) {
    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    // A post a person is reading, or sent back: say so, and what to do next (D17).
    if (job.heldForScreening || job.needsChange) {
      final held = job.heldForScreening;
      return KdCard(
        onTap: () => held
            ? showKdSheet(
                context,
                builder: (sheet) => KdSheetBody(
                  title: 'A person is reading it',
                  lead: "A new client's first post is read by a person before it goes live, to keep talents safe. You will be told here and by email as soon as it is live.",
                  children: [const SizedBox(height: 14), KdButton(label: 'Got it', onPressed: () => Navigator.of(sheet).pop())],
                ),
              )
            : open(PostJobFlow(editing: job, onPosted: () => Navigator.of(context).pop())),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(job.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, height: 1.3))),
                const SizedBox(width: 10),
                held ? const StatusPill('Being read', tone: KdTone.warn, pulse: true) : const StatusPill('Needs a change', tone: KdTone.warn),
              ],
            ),
            const SizedBox(height: 6),
            Text(held ? 'Not live yet. Nobody can see it until a person has read it.' : 'Sent back. Change it and it goes for another look.', style: AppTextStyles.bodySmall),
            if (!held) ...[const SizedBox(height: 10), Text('Change it', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryText))],
          ],
        ),
      );
    }
    if (job.contractStatus == null) {
      return KdCard(
        onTap: () => open(ApplicantsScreen(job: job)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(job.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, height: 1.3))),
                const SizedBox(width: 10),
                job.closed ? const StatusPill('Closed') : job.paused ? const StatusPill('Paused', tone: KdTone.warn) : const StatusPill('Open', tone: KdTone.brand),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(job.isStructured ? '${job.skillOrCategory} · ${job.jobType.label}' : job.category, style: AppTextStyles.bodySmall)),
                Text('${formatMoney(job.budget, job.currency)}${job.jobType.priceNote}', style: AppTextStyles.title.copyWith(color: AppColors.money)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.closed
                        ? (job.applicationCount == 0 ? 'Closed' : 'Closed · ${job.applicationCount} applicant${job.applicationCount == 1 ? '' : 's'}')
                        : job.paused
                            ? 'Paused · ${job.applicationCount} applicant${job.applicationCount == 1 ? '' : 's'} · reopen for more'
                        : job.applicationCount == 0
                            ? 'No applicants yet'
                            : '${job.applicationCount} applicant${job.applicationCount == 1 ? '' : 's'} · pick one',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: job.closed || job.applicationCount == 0 ? AppColors.text3 : AppColors.primaryText,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
              ],
            ),
          ],
        ),
      );
    }
    return ContractTile(
      job: job,
      forClient: true,
      who: job.category,
      onTap: () => open(job.contractStatus == ContractStatus.awaitingPayment ? FundContractScreen(jobId: job.id) : ClientContractScreen(jobId: job.id)),
    );
  }
}
