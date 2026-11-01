import 'package:flutter/material.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/job.dart';
import '../kit/kd_card.dart';
import '../kit/status_pill.dart';
import 'contract_parts.dart';

enum StepProgress { done, current, later }

class LifecycleStep {
  final String label;
  final String? subtitle;
  final StepProgress progress;
  final KdTone tone;
  final IconData icon;
  const LifecycleStep({required this.label, required this.subtitle, required this.progress, required this.tone, required this.icon});
}

const _icons = [
  Icons.how_to_reg_outlined,
  Icons.lock_outline_rounded,
  Icons.work_outline_rounded,
  Icons.rate_review_outlined,
  Icons.account_balance_outlined,
];

/// The five steps of a contract, derived only from the contract's status and
/// dates. The words say what happened ("has paid", "paid to your payout
/// account"), never where money is held.
List<LifecycleStep> lifecycleSteps(Job job, {required bool forClient}) {
  final status = job.contractStatus!;
  final current = switch (status) {
    ContractStatus.awaitingPayment => 1,
    ContractStatus.funded || ContractStatus.inProgress || ContractStatus.changesRequested => 2,
    ContractStatus.submitted || ContractStatus.disputed => 3,
    ContractStatus.approved || ContractStatus.resolved => -1,
  };
  final allDone = status == ContractStatus.approved;

  StepProgress progressOf(int i) => allDone || i < current ? StepProgress.done : (i == current ? StepProgress.current : StepProgress.later);

  final overdue = status == ContractStatus.inProgress && job.overdue;
  // Violet when it is the viewer's turn, amber when they are waiting on someone.
  // An in-progress job is the talent's turn, though nothing is "needed" of them yet.
  final yourTurn = status == ContractStatus.inProgress ? !forClient : contractNeedsYou(job, forClient: forClient);
  final currentTone = status == ContractStatus.disputed || overdue ? KdTone.bad : (yourTurn ? KdTone.brand : KdTone.warn);

  final client = job.clientName;
  String left(DateTime? t, String unknown) => t == null ? unknown : (timeLeft(t) ?? 'now');

  String? subtitle(int i, StepProgress p) {
    switch (i) {
      case 0:
        return forClient ? 'You picked a talent' : 'Picked by $client';
      case 1:
        if (p == StepProgress.current) {
          return forClient ? 'Pay within ${left(job.payByAt, '24 hours')}' : 'Waiting for $client to pay';
        }
        if (p == StepProgress.done) return forClient ? 'You paid ${formatNaira(job.clientTotal)}' : '$client has paid';
        return null;
      case 2:
        if (p == StepProgress.current) {
          return switch (status) {
            ContractStatus.funded => forClient ? 'Waiting for the talent to start' : 'Start when you\'re ready',
            ContractStatus.changesRequested => 'Changes requested, round ${job.changeRounds} of ${Job.maxChangeRounds}',
            _ => overdue ? '3 days past the delivery date' : (job.deliverByAt == null ? 'In progress' : 'Due in ${left(job.deliverByAt, 'time')}'),
          };
        }
        return p == StepProgress.done ? 'Delivered' : null;
      case 3:
        if (status == ContractStatus.disputed) return 'With a ${AppBrand.name} admin';
        if (p == StepProgress.current) {
          if (forClient) return 'Review it now';
          return job.reviewDueAt == null ? 'Waiting for $client' : 'Waiting for $client · by ${formatDeadline(job.reviewDueAt!)}';
        }
        return p == StepProgress.done ? 'Approved' : 'Up to 3 days to approve or ask for changes';
      default:
        return forClient ? 'Paid out to the talent' : 'Paid to your payout account';
    }
  }

  const labels = ['Awarded', 'Payment secured', 'Working on it', 'Client reviews'];
  return [
    for (var i = 0; i < 5; i++)
      LifecycleStep(
        label: i < 4 ? labels[i] : (forClient ? 'Talent is paid' : 'You\'re paid'),
        subtitle: subtitle(i, progressOf(i)),
        progress: progressOf(i),
        tone: progressOf(i) == StepProgress.current ? currentTone : (progressOf(i) == StepProgress.done ? KdTone.ok : KdTone.plain),
        icon: _icons[i],
      ),
  ];
}

/// The contract's five steps as a vertical rail: done (green check), the
/// current one in the tone of whose turn it is, later ones muted.
class LifecycleStepper extends StatelessWidget {
  final Job job;
  final bool forClient;
  const LifecycleStepper({super.key, required this.job, required this.forClient});

  @override
  Widget build(BuildContext context) {
    // A settled job has no happy path left to show: the card above says how it ended.
    if (job.contractStatus == ContractStatus.resolved) return const SizedBox.shrink();
    final steps = lifecycleSteps(job, forClient: forClient);
    return KdCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        children: [for (var i = 0; i < steps.length; i++) _StepRow(index: i, step: steps[i], last: i == steps.length - 1)],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final LifecycleStep step;
  final bool last;
  const _StepRow({required this.index, required this.step, required this.last});

  @override
  Widget build(BuildContext context) {
    final done = step.progress == StepProgress.done;
    final current = step.progress == StepProgress.current;
    final ink = done ? AppColors.ok : (current ? toneInk(step.tone) : AppColors.text3);
    final nodeFill = done ? AppColors.okSoft : (current ? toneSurface(step.tone) : AppColors.surface3);
    final stateWord = done ? 'done' : (current ? 'current' : 'later');
    final waiting = current && step.tone == KdTone.warn;

    return Semantics(
      container: true,
      label: 'Step ${index + 1} of 5: ${step.label}, $stateWord${step.subtitle == null ? '' : ', ${step.subtitle}'}',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: nodeFill, shape: BoxShape.circle),
                      child: Icon(done ? Icons.check_rounded : step.icon, size: 16, color: ink),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: done ? AppColors.ok : AppColors.surface3),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 6 : 14, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              step.label,
                              style: AppTextStyles.title.copyWith(
                                fontSize: 14.5,
                                color: step.progress == StepProgress.later ? AppColors.text3 : AppColors.text,
                              ),
                            ),
                          ),
                          if (waiting) ...[const SizedBox(width: 8), PulseDot(color: ink, size: 6)],
                        ],
                      ),
                      if (step.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(step.subtitle!, style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5, color: current ? ink : AppColors.text2)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
