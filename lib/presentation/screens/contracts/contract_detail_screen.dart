import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/common/section_label.dart';
import 'submit_deliverable_screen.dart';

/// The wedge's core screen (docs/core/vision-vs-research-reconciliation.md
/// §2): makes payment protection legible in plain language, not a fintech
/// dashboard. There is no real escrow integration yet — for the first real
/// transactions, the founding team moves money manually and this status is
/// updated by hand to match. The point is testing whether the *promise*
/// ("you'll be paid once the client approves") changes how safe a student
/// feels delivering work to a stranger, before any payment infrastructure
/// is built.
class ContractDetailScreen extends ConsumerWidget {
  final String jobId;

  const ContractDetailScreen({super.key, required this.jobId});

  static const _steps = [
    ContractStatus.funded,
    ContractStatus.inProgress,
    ContractStatus.submitted,
    ContractStatus.approved,
  ];

  String _stepLabel(ContractStatus status) => switch (status) {
    ContractStatus.funded => 'Funded',
    ContractStatus.inProgress => 'In progress',
    ContractStatus.submitted => 'Submitted',
    ContractStatus.approved => 'Approved',
  };

  String _explanation(ContractStatus status, Job job) => switch (status) {
    ContractStatus.funded =>
      '${job.clientName} has funded this job. The money is set aside — '
          'you\'ll be paid once they approve your delivery.',
    ContractStatus.inProgress =>
      'You\'ve started work. Submit your deliverable when it\'s ready for '
          '${job.clientName} to review.',
    ContractStatus.submitted =>
      'Your work is with ${job.clientName} for review. You\'ll be paid as '
          'soon as they approve it.',
    ContractStatus.approved =>
      '${job.clientName} approved your delivery. Payment has been released '
          'to you.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobsProvider).firstWhere((j) => j.id == jobId);
    final status = job.contractStatus;

    if (status == null) {
      // Accepted but not yet funded shouldn't be reachable in the wedge
      // (accept-and-fund happen together), but fail into something legible
      // rather than crashing if state ever gets here.
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Waiting on the client to fund this job.')),
      );
    }

    final stepIndex = _steps.indexOf(status);

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
                        status == ContractStatus.approved
                            ? Icons.check_circle
                            : Icons.shield_outlined,
                        size: AppDimensions.iconSm,
                        color: status == ContractStatus.approved
                            ? AppColors.settled
                            : AppColors.gold,
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Text(
                        '\$${job.budget.toStringAsFixed(0)}',
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
            const SizedBox(height: AppDimensions.xl),

            if (status == ContractStatus.funded)
              ElevatedButton(
                onPressed: () => ref.read(jobsProvider.notifier).startWork(job.id),
                child: const Text('Start work'),
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
                const SizedBox(height: AppDimensions.lg),
              ],
              OutlinedButton(
                onPressed: () =>
                    ref.read(jobsProvider.notifier).simulateClientApproval(job.id),
                child: const Text('Simulate client approval'),
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
