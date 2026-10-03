import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/contract_history.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';

/// The client's view of a paid contract (prototypes/stage2-contract-flow.html,
/// right phone): progress toward the delivery date, extension requests to
/// answer, the delivered versions to review, approve (the real payout) or ask
/// for changes. Payment before this point is FundContractScreen.
class ClientContractScreen extends ConsumerWidget {
  final String jobId;
  const ClientContractScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    return Scaffold(
      body: jobsAsync.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => _centered(
          context,
          'Couldn\'t load this job. Check your connection and try again.',
          KdButton.secondary(label: 'Try again', onPressed: () => ref.read(jobsProvider.notifier).refresh()),
        ),
        data: (jobs) {
          final job = jobs.where((j) => j.id == jobId).firstOrNull;
          if (job == null || job.contractStatus == null) return _centered(context, 'This job has no contract yet.', null);
          return LiveClock(builder: (_) => _ClientContract(job: job));
        },
      ),
    );
  }

  Widget _centered(BuildContext context, String text, Widget? action) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
          const Spacer(),
          Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)),
          if (action != null) ...[const SizedBox(height: 16), SizedBox(width: 200, child: action)],
          const Spacer(),
        ],
      ),
    ),
  );
}

class _ClientContract extends ConsumerWidget {
  final Job job;
  const _ClientContract({required this.job});

  String get talent => 'The talent';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = job.contractStatus!;
    final history = ref.watch(contractHistoryProvider(job.id)).valueOrNull ?? const ContractHistory();
    final cards = <Widget>[
      ..._stateCards(context, ref, status, history),
      if (history.deliveries.isNotEmpty) VersionsCard(
          versions: history.deliveries,
          title: 'Delivered work',
          refreshLinks: () async => (await ref.refresh(contractHistoryProvider(job.id).future)).deliveries,
        ),
    ];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(contractHistoryProvider(job.id));
            await ref.read(jobsProvider.notifier).refresh();
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 220),
            children: [
              ContractHeader(
                title: job.title,
                sub: '${formatNaira(job.budget)} held by ${AppBrand.name}',
                pill: contractStatusPill(status),
              ),
              for (var i = 0; i < cards.length; i++)
                Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 60 * i), child: cards[i])),
            ],
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: ActionBar(children: _actions(context, ref, status))),
      ],
    );
  }

  List<Widget> _stateCards(BuildContext context, WidgetRef ref, ContractStatus status, ContractHistory history) {
    final deadline = job.deliverByAt;
    switch (status) {
      case ContractStatus.awaitingPayment:
        return [
          const NoticeCard(tone: KdTone.warn, icon: Icons.hourglass_empty_rounded, title: 'Waiting for your payment', body: 'Pay from the job to start the work.'),
        ];
      case ContractStatus.funded:
      case ContractStatus.inProgress:
        return [
          if (deadline != null)
            DeadlineCard(
              eyebrow: status == ContractStatus.funded ? 'Due in (not started yet)' : 'Delivery due in',
              deadline: deadline,
              start: job.fundedAt,
              lateNote: 'They can still deliver',
            ),
          if (job.overdue)
            const NoticeCard(
              tone: KdTone.bad,
              icon: Icons.error_outline_rounded,
              title: '3 days past the delivery date',
              body: 'Nothing has been delivered and no extension was agreed. We\'ve recorded this on the job. '
                  'Cancelling for a refund of the budget isn\'t available in the app yet.',
            ),
          ?_extensionCard(context, ref, history),
        ];
      case ContractStatus.submitted:
        return [
          if (job.reviewDueAt != null)
            NoticeCard(
              tone: KdTone.warn,
              icon: Icons.schedule_rounded,
              title: 'Review by ${formatDeadline(job.reviewDueAt!)}',
              body: 'If you do nothing, payment is released to the talent automatically.',
            ),
          NoticeCard(
            tone: KdTone.plain,
            icon: Icons.verified_user_outlined,
            title: 'Your call',
            body: 'Approving sends ${formatNaira(job.budget)} to the talent\'s bank account and can\'t be undone. '
                'If something isn\'t right, ask for changes (${job.changeRoundsLeft} round${job.changeRoundsLeft == 1 ? '' : 's'} left).',
          ),
        ];
      case ContractStatus.changesRequested:
        final round = history.latestChangeRound;
        final due = job.changeDueAt;
        return [
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.edit_outlined,
            title: 'You asked for changes',
            trailing: 'Round ${job.changeRounds} of ${Job.maxChangeRounds}',
            extra: RoundSteps(current: job.changeRounds),
            quote: round?.reason,
            waiting: due == null ? null : switch (timeLeft(due)) { final l? => 'The talent resubmits within $l', null => 'The resubmit time has run out' },
            footnote: 'If they don\'t resubmit in time, the job goes to a ${AppBrand.name} admin.',
          ),
        ];
      case ContractStatus.disputed:
        return [
          const NoticeCard(
            tone: KdTone.bad,
            icon: Icons.balance_rounded,
            title: 'With a ${AppBrand.name} admin',
            body: 'An admin will look at every version and change request and decide. They can split the payment if the work is partly done. '
                'Nothing is paid out or refunded until then.',
          ),
        ];
      case ContractStatus.approved:
        return [
          NoticeCard(
            tone: KdTone.ok,
            icon: Icons.payments_outlined,
            title: 'You approved. ${formatNaira(job.budget)} sent',
            body: 'Thanks for paying through ${AppBrand.name}.',
          ),
        ];
    }
  }

  Widget? _extensionCard(BuildContext context, WidgetRef ref, ContractHistory history) {
    final e = history.latestExtension;
    if (e == null || e.status == ExtensionStatus.withdrawn) return null;
    final days = '${e.requestedDays} more day${e.requestedDays == 1 ? '' : 's'}';
    if (e.status != ExtensionStatus.pending) {
      return NoticeCard(
        tone: e.status == ExtensionStatus.declined ? KdTone.plain : KdTone.ok,
        icon: e.status == ExtensionStatus.declined ? Icons.info_outline_rounded : Icons.check_rounded,
        title: switch (e.status) {
          ExtensionStatus.declined => 'You declined the extension',
          ExtensionStatus.autoGranted => 'Extension granted automatically (no answer in 48 hours)',
          _ => 'You gave $days',
        },
        body: job.deliverByAt == null ? null : 'Delivery date: ${formatDeadline(job.deliverByAt!)}.',
      );
    }
    final current = job.deliverByAt;
    return NoticeCard(
      tone: KdTone.warn,
      icon: Icons.hourglass_top_rounded,
      title: 'The talent asked for $days',
      quote: e.reason,
      body: current == null ? null : 'The delivery date would move from ${formatDeadline(current)} to ${formatDeadline(current.add(Duration(days: e.requestedDays)))}.',
      waiting: switch (timeLeft(e.answerDueAt)) { final l? => 'Answer within $l, or it\'s granted automatically', null => 'Being granted now' },
      actions: [
        KdButton(label: 'Decline', variant: KdButtonVariant.secondary, height: AppDimensions.buttonHeightSm, onPressed: () { _confirmDecline(context, ref, e); }),
        KdButton(
          label: 'Give $days',
          variant: KdButtonVariant.soft,
          height: AppDimensions.buttonHeightSm,
          busyLabel: 'Granting',
          onPressed: () => _answer(context, ref, e, grant: true),
        ),
      ],
    );
  }

  Future<void> _answer(BuildContext context, WidgetRef ref, ExtensionRequest e, {required bool grant}) async {
    try {
      await ref.read(jobsProvider.notifier).answerExtension(job.id, e.id, grant: grant);
    } on ApiException catch (err) {
      if (context.mounted) KdToast.show(context, err.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (context.mounted) KdToast.show(context, grant ? 'Extension granted' : 'Extension declined', kind: grant ? ToastKind.ok : ToastKind.info);
  }

  Future<void> _confirmDecline(BuildContext context, WidgetRef ref, ExtensionRequest e) {
    final left = job.extensionRequestsLeft;
    return showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Decline the extension?',
        lead: 'The delivery date stays ${job.deliverByAt == null ? 'as it is' : formatDeadline(job.deliverByAt!)}. '
            'The talent has $left request${left == 1 ? '' : 's'} left on this job.',
        children: [
          const SizedBox(height: 18),
          KdButton(
            label: 'Decline',
            variant: KdButtonVariant.danger,
            busyLabel: 'Declining',
            onPressed: () async {
              await _answer(sheet, ref, e, grant: false);
              if (sheet.mounted) Navigator.of(sheet).pop();
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep it open', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, ContractStatus status) {
    if (status != ContractStatus.submitted) return const [];
    final last = job.changeRounds >= Job.maxChangeRounds;
    return [
      KdButton(label: 'Approve and pay ${formatNaira(job.budget)}', onPressed: () { _confirmApprove(context, ref); }),
      KdButton.secondary(
        label: last ? 'Still not right? Ask an admin' : 'Ask for changes · ${job.changeRoundsLeft} round${job.changeRoundsLeft == 1 ? '' : 's'} left',
        onPressed: () { showKdSheet(context, builder: (_) => _ChangesSheet(job: job)); },
      ),
    ];
  }

  Future<void> _confirmApprove(BuildContext context, WidgetRef ref) {
    return showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Approve and pay ${formatNaira(job.budget)}?',
        lead: 'The talent is paid from the money you already paid in. This can\'t be undone.',
        children: [
          const SizedBox(height: 18),
          KdButton(
            label: 'Approve and pay',
            busyLabel: 'Paying the talent',
            onPressed: () async {
              try {
                await ref.read(jobsProvider.notifier).approveDelivery(job.id);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!sheet.mounted) return;
              Navigator.of(sheet).pop();
              KdToast.show(sheet, 'Approved · ${formatNaira(job.budget)} on its way to the talent');
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Not yet', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }
}

class _ChangesSheet extends ConsumerStatefulWidget {
  final Job job;
  const _ChangesSheet({required this.job});

  @override
  ConsumerState<_ChangesSheet> createState() => _ChangesSheetState();
}

class _ChangesSheetState extends ConsumerState<_ChangesSheet> {
  final _reason = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final last = job.changeRounds >= Job.maxChangeRounds;
    final round = job.changeRounds + 1;
    return KdSheetBody(
      title: last ? 'Ask a ${AppBrand.name} admin' : 'Ask for changes',
      lead: last
          ? 'You\'ve used both change rounds. An admin will look at every version and your requests, then decide. '
              'They can split the payment if the work is partly done. Nothing is paid out until then.'
          : 'This is round $round of ${Job.maxChangeRounds}. The talent gets 3 days to resubmit.'
              '${round == Job.maxChangeRounds ? ' After this round, if it\'s still not right, an admin decides.' : ''}',
      children: [
        ReasonField(
          controller: _reason,
          label: last ? 'What\'s still wrong?' : 'What needs changing?',
          hint: 'Be specific: what, where, and what you expected.',
          onValidChanged: (v) => setState(() => _valid = v),
        ),
        const SizedBox(height: 18),
        KdButton(
          label: last ? 'Send to an admin' : 'Send to the talent',
          busyLabel: 'Sending',
          onPressed: !_valid
              ? null
              : () async {
                  final bool escalated;
                  try {
                    escalated = await ref.read(jobsProvider.notifier).requestChanges(job.id, reason: _reason.text);
                  } on ApiException catch (e) {
                    if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
                    throw const ShownError();
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  KdToast.show(context, escalated ? 'Sent to a ${AppBrand.name} admin' : 'Changes requested', kind: escalated ? ToastKind.info : ToastKind.ok);
                },
        ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
