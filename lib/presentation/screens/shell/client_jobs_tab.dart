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
import '../payments/fund_contract_screen.dart';
import 'work_tab.dart';

/// C0 — My jobs (client): jobs this client posted, filtered from the shared
/// feed by clientId. Open jobs show their applicants; awarded ones open the
/// contract (or payment, while unpaid).
class ClientJobsTab extends ConsumerWidget {
  final VoidCallback onPostJob;
  const ClientJobsTab({super.key, required this.onPostJob});

  static List<Job> mine(List<Job> jobs, String? clientId) => jobs.where((j) => j.clientId == clientId).toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    final jobs = mine(jobsAsync.valueOrNull ?? const [], ref.watch(authProvider).user?.id);
    // Needing you first; open jobs (no contract) rank with the active ones.
    jobs.sort((a, b) => (a.contractStatus == null ? 1 : contractSortRank(a, forClient: true)) - (b.contractStatus == null ? 1 : contractSortRank(b, forClient: true)));

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
                const StatusPill('Open', tone: KdTone.brand),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(job.category, style: AppTextStyles.bodySmall)),
                Text(formatNaira(job.budget), style: AppTextStyles.title.copyWith(color: AppColors.money)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.applicationCount == 0
                        ? 'No applicants yet'
                        : '${job.applicationCount} applicant${job.applicationCount == 1 ? '' : 's'} · pick one',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: job.applicationCount == 0 ? AppColors.text3 : AppColors.primaryText,
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
