import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/common/section_label.dart';
import '../payments/payout_account_screen.dart';
import 'submit_deliverable_screen.dart';

/// The wedge's core screen (docs/core/vision-vs-research-reconciliation.md
/// §2): makes payment protection legible in plain language, not a fintech
/// dashboard. Backed by real money now — "funded" means the client's
/// payment is confirmed by Paystack and held in King Domain's balance, and
/// approval transfers the budget to the talent's payout account.
class ContractDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const ContractDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends ConsumerState<ContractDetailScreen> {
  bool _startingWork = false;
  String? _error;

  static const _steps = [
    ContractStatus.funded,
    ContractStatus.inProgress,
    ContractStatus.submitted,
    ContractStatus.approved,
  ];

  String _stepLabel(ContractStatus status) => switch (status) {
    ContractStatus.awaitingPayment => 'Awaiting payment',
    ContractStatus.funded => 'Funded',
    ContractStatus.inProgress => 'In progress',
    ContractStatus.submitted => 'Submitted',
    ContractStatus.approved => 'Approved',
  };

  String _explanation(ContractStatus status, Job job) => switch (status) {
    ContractStatus.awaitingPayment =>
      '${job.clientName} selected you. They still need to pay before work '
          'starts — don\'t begin until this contract shows Funded.'
          '${job.payByAt == null ? '' : ' They have until ${formatDeadline(job.payByAt!)}; if it isn\'t paid by then the award is cancelled and you\'re back in the running.'}',
    ContractStatus.funded =>
      '${job.clientName} has funded this job. The money is set aside — '
          'you\'ll be paid once they approve your delivery.',
    ContractStatus.inProgress =>
      'You\'ve started work. Submit your deliverable when it\'s ready for '
          '${job.clientName} to review.',
    ContractStatus.submitted =>
      'Your work is with ${job.clientName} for review. You\'ll be paid as '
          'soon as they approve it.'
          '${job.reviewDueAt == null ? '' : ' If they don\'t respond by ${formatDeadline(job.reviewDueAt!)}, you\'re paid automatically.'}',
    ContractStatus.approved =>
      '${job.clientName} approved your delivery. Payment has been sent to '
          'your payout account.',
  };

  Future<void> _startWork(String jobId) async {
    setState(() {
      _startingWork = true;
      _error = null;
    });
    try {
      await ref.read(jobsProvider.notifier).startWork(jobId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _startingWork = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);

    return jobsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not load this contract.', style: AppTextStyles.bodyMedium)),
      ),
      data: (jobs) => _buildBody(context, jobs.firstWhere((j) => j.id == widget.jobId)),
    );
  }

  Widget _buildBody(BuildContext context, Job job) {
    final status = job.contractStatus;

    if (status == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This job has no contract yet.')),
      );
    }

    // -1 for awaitingPayment: nothing lit on the stepper until money is in.
    final stepIndex = _steps.indexOf(status);
    final needsPayoutAccount = status != ContractStatus.approved &&
        ref.watch(talentProfileProvider).valueOrNull?.payoutAccount == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Contract')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          children: [
            SectionLabel(job.category),
            const SizedBox(height: AppDimensions.sm),
            Text(job.title, style: AppTextStyles.h3),
            const SizedBox(height: AppDimensions.xl),

            _StatusStepper(currentIndex: stepIndex, labels: _steps.map(_stepLabel).toList()),
            const SizedBox(height: AppDimensions.lg),

            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        switch (status) {
                          ContractStatus.approved => Icons.check_circle,
                          ContractStatus.awaitingPayment => Icons.hourglass_empty,
                          _ => Icons.shield_outlined,
                        },
                        size: AppDimensions.iconSm,
                        color: switch (status) {
                          ContractStatus.approved => AppColors.settled,
                          ContractStatus.awaitingPayment => AppColors.openPending,
                          _ => AppColors.gold,
                        },
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Text(
                        formatNaira(job.budget),
                        style: AppTextStyles.h3.copyWith(color: AppColors.paper),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    _explanation(status, job),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.slateDim,
                    ),
                  ),
                ],
              ),
            ),
            if (needsPayoutAccount) ...[
              const SizedBox(height: AppDimensions.md),
              _PayoutPrompt(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PayoutAccountScreen()),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppDimensions.md),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
              ),
            ],
            const SizedBox(height: AppDimensions.xl),

            if (status == ContractStatus.funded)
              ElevatedButton(
                onPressed: _startingWork ? null : () => _startWork(job.id),
                child: _startingWork
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.ink,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Start work'),
              ),
            if (status == ContractStatus.inProgress)
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubmitDeliverableScreen(jobId: job.id),
                  ),
                ),
                child: const Text('Submit deliverable'),
              ),
            if (status == ContractStatus.submitted) ...[
              if (job.deliverableNote != null) ...[
                const SectionLabel('Your submission'),
                const SizedBox(height: AppDimensions.sm),
                Text(job.deliverableNote!, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppDimensions.sm),
              ],
              if (job.deliverableFileUrl != null) ...[
                Row(
                  children: [
                    Icon(Icons.attach_file, size: AppDimensions.iconSm, color: AppColors.slateDim),
                    const SizedBox(width: AppDimensions.sm),
                    Text('File attached', style: AppTextStyles.bodySmall),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),
              ] else
                const SizedBox(height: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.openPending.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.openPending.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, size: AppDimensions.iconSm, color: AppColors.openPending),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'Waiting on ${job.clientName} to review and approve.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == ContractStatus.approved)
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.settled.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.settled.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: AppDimensions.iconSm, color: AppColors.settled),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        'Payment released — this job is complete.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.settled),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PayoutPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _PayoutPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_outlined, size: AppDimensions.iconSm, color: AppColors.gold),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a payout account',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gold, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The client can\'t release your payment until you add the bank account it goes to.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: AppDimensions.iconSm, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final int currentIndex;
  final List<String> labels;

  const _StatusStepper({required this.currentIndex, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= currentIndex ? AppColors.settled : AppColors.ink3,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: i <= currentIndex ? AppColors.settled : AppColors.slateDim,
                    fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (i != labels.length - 1) const SizedBox(width: AppDimensions.xs),
        ],
      ],
    );
  }
}
