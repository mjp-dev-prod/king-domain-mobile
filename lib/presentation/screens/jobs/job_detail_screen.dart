import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import '../payments/payout_account_screen.dart';
import '../profile/profile_overview_screen.dart';

/// T5 — Job detail (prototypes/palette-explorer.html, screen 02). What the
/// job is, what it pays and by when, and whether this talent can apply,
/// stated plainly. Applying shows exactly what the client will see.
///
/// Only real data: there is no client verification or rating system yet, so
/// the client card shows a name and nothing invented.
class JobDetailScreen extends ConsumerWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    final job = jobsAsync.valueOrNull?.where((j) => j.id == jobId).firstOrNull;
    final profile = ref.watch(talentProfileProvider).valueOrNull;

    if (job == null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.gutter),
            child: jobsAsync.isLoading
                ? const Column(children: [SizedBox(height: 60), SkeletonCard(), SizedBox(height: 12), SkeletonCard()])
                : Column(
                    children: [
                      Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
                      ErrorState(message: 'Couldn\'t load this job.', onRetry: () => ref.read(jobsProvider.notifier).refresh()),
                    ],
                  ),
          ),
        ),
      );
    }

    final verified = profile?.isVerifiedIn(job.category) ?? false;
    final hasPayout = profile?.payoutAccount != null;
    final applied = job.applicationStatus != JobApplicationStatus.notApplied;
    final filled = job.awardedApplicationId != null;

    final cards = <Widget>[
      _Hero(job: job),
      ?_gate(context, job, verified: verified, hasPayout: hasPayout, applied: applied),
      KdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About the job', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text(job.description, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2, height: 1.6)),
          ],
        ),
      ),
      KdCard(
        child: Row(
          children: [
            InitialsAvatar(name: job.clientName, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.clientName, style: AppTextStyles.title),
                  Text('Client · pays into ${AppBrand.name} before you start', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    ];

    final StatusPill? appliedPill = switch (job.applicationStatus) {
      JobApplicationStatus.pending => const StatusPill('Applied', tone: KdTone.brand),
      JobApplicationStatus.accepted => const StatusPill('You were selected', tone: KdTone.ok, icon: Icons.check_rounded),
      JobApplicationStatus.rejected => const StatusPill('Not selected'),
      JobApplicationStatus.notApplied => null,
    };

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 200),
            children: [
              ContractHeader(
                title: job.title,
                sub: 'Posted ${formatAgo(job.postedAt)}',
                pill: appliedPill ?? StatusPill(job.category, tone: KdTone.brand),
              ),
              for (var i = 0; i < cards.length; i++)
                Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 60 * i), child: cards[i])),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ActionBar(
              children: [
                if (!applied && !filled)
                  KdButton(
                    label: !verified ? 'Verified proof needed to apply' : !hasPayout ? 'Add a payout account to apply' : 'Apply for this job',
                    onPressed: verified && hasPayout ? () { _confirmApply(context, ref, job, profile!); } : null,
                  ),
                if (job.applicationStatus == JobApplicationStatus.pending)
                  Text('${job.clientName} will see your application with your verified proof.', textAlign: TextAlign.center, style: AppTextStyles.hint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The one thing standing between this talent and applying, if anything.
  Widget? _gate(BuildContext context, Job job, {required bool verified, required bool hasPayout, required bool applied}) {
    if (applied) return null;
    if (!verified) {
      return NoticeCard(
        tone: KdTone.plain,
        icon: Icons.lock_outline_rounded,
        title: 'Verified proof in ${job.category} needed',
        body: 'Add a real piece of work in this category. A ${AppBrand.name} reviewer checks it, then you can apply.',
        actions: [
          KdButton(
            label: 'Add proof',
            variant: KdButtonVariant.soft,
            height: AppDimensions.buttonHeightSm,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileOverviewScreen())),
          ),
        ],
      );
    }
    if (!hasPayout) {
      return NoticeCard(
        tone: KdTone.warn,
        icon: Icons.account_balance_outlined,
        title: 'Add a payout account to apply',
        body: 'It\'s where you\'re paid when the client approves your work.',
        actions: [
          KdButton(
            label: 'Add bank account',
            variant: KdButtonVariant.soft,
            height: AppDimensions.buttonHeightSm,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutAccountScreen())),
          ),
        ],
      );
    }
    return NoticeCard(
      tone: KdTone.ok,
      icon: Icons.verified_outlined,
      title: 'You can apply',
      body: 'Your proof in ${job.category} is verified. The client sees it with your application.',
    );
  }

  void _confirmApply(BuildContext context, WidgetRef ref, Job job, TalentProfile profile) {
    final proof = profile.proofItems.where((p) => p.category == job.category && p.status == ProofReviewStatus.verified).toList();
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Apply for this job?',
        lead: '${job.clientName} will see your name, your profile and your verified proof in ${job.category}. '
            'If they pick you, they pay the ${formatNaira(job.budget)} budget into ${AppBrand.name} before you start.',
        children: [
          const SizedBox(height: 14),
          for (final p in proof)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KdCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 18, color: AppColors.ok),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          KdButton(
            label: 'Send application',
            busyLabel: 'Sending',
            onPressed: () async {
              try {
                await ref.read(jobsProvider.notifier).applyTo(job.id);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!sheet.mounted) return;
              Navigator.of(sheet).pop();
              KdToast.show(sheet, 'Application sent to ${job.clientName}');
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Not now', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }
}

/// The budget (in gold: money's one colour), delivery time, applicants and
/// the agreed change limit.
class _Hero extends StatelessWidget {
  final Job job;
  const _Hero({required this.job});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.hint),
            const SizedBox(height: 2),
            Text(value, style: AppTextStyles.title.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
    return KdCard(
      hero: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatNaira(job.budget), style: AppTextStyles.figure.copyWith(color: AppColors.money)),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('paid to you when the client approves', style: AppTextStyles.bodySmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile('Delivery', job.deliveryDays == null ? 'Agree with client' : '${job.deliveryDays} day${job.deliveryDays == 1 ? '' : 's'}'),
              const SizedBox(width: 8),
              tile('Applied', '${job.applicationCount}'),
              const SizedBox(width: 8),
              tile('Changes', 'Up to ${Job.maxChangeRounds}'),
            ],
          ),
        ],
      ),
    );
  }
}
