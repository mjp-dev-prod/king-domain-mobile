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
import '../../widgets/contract/lifecycle_stepper.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../contracts/dispute_screen.dart';
import '../contracts/drafts_screen.dart';
import '../contracts/receipt_screen.dart';
import '../contracts/review_screen.dart';
import '../contracts/start_proof_screen.dart';

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

  /// The first 20% was already paid on the start proof; approval pays the rest.
  bool get _paidUpfront => job.upfrontPaidAt != null && job.upfrontAmount != null;
  double get _remaining => job.budget - (_paidUpfront ? job.upfrontAmount! : 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = job.contractStatus!;
    final history = ref.watch(contractHistoryProvider(job.id)).valueOrNull ?? const ContractHistory();
    final state = _stateCards(context, ref, status, history);
    final proofCard = _startProofCard(context);
    final disputeCard = job.disputeOpen
        ? NoticeCard(
            tone: KdTone.warn,
            icon: Icons.report_gmailerrorred_outlined,
            title: 'A problem is open on this job',
            body: 'Delivery dates, your review time and automatic payment are paused while you sort it out. Nothing is paid or refunded until it is settled.',
            actions: [KdButton(label: 'See where it stands', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: () => _openDispute(context))],
          )
        : null;
    final working = status == ContractStatus.funded || status == ContractStatus.inProgress || status == ContractStatus.changesRequested;
    final delivered = history.deliveries.isEmpty
        ? null
        : VersionsCard(
            versions: history.deliveries,
            title: 'Delivered work',
            refreshLinks: () async => (await ref.refresh(contractHistoryProvider(job.id).future)).deliveries,
          );
    // While the client is deciding, the work leads: "Approve and pay" stays on screen, so what it pays for can't sit under
    // the links. Afterwards the links lead, because the next step is one of them (reviewing the talent).
    final deciding = status == ContractStatus.submitted;
    final cards = <Widget>[
      ?disputeCard,
      if (proofCard != null && proofCard.$2) proofCard.$1 else if (state.isNotEmpty) state.first,
      LifecycleStepper(job: job, forClient: true),
      if (proofCard != null && proofCard.$2) ...state,
      if (proofCard != null && !proofCard.$2) proofCard.$1,
      if (proofCard == null || !proofCard.$2) ...state.skip(1),
      if (deciding) ?delivered,
      if (status != ContractStatus.awaitingPayment) ...[
        if (status != ContractStatus.approved && status != ContractStatus.resolved)
          ContractLinkTile(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'Something\'s wrong',
            sub: job.disputeOpen || status == ContractStatus.disputed ? 'See where it stands' : 'Work it out with the talent, or ask us to decide',
            onTap: () => _openDispute(context),
          ),
        ContractLinkTile(
          icon: Icons.draw_outlined,
          title: 'Drafts',
          sub: working ? 'Work in progress the talent has shown you' : 'Work shown along the way',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DraftsScreen(jobId: job.id, jobTitle: job.title, forClient: true, canShare: false))),
        ),
        if (status == ContractStatus.approved || (status == ContractStatus.resolved && (job.settledTalentAmount ?? 0) > 0))
          ContractLinkTile(icon: Icons.rate_review_outlined, title: 'Review the talent', sub: 'Specific questions, no stars. Hidden until both are in', onTap: () => _openReview(context)),
        ContractLinkTile(
          icon: Icons.receipt_long_outlined,
          title: 'Receipt',
          sub: 'The record of what you paid',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(jobId: job.id))),
        ),
      ],
      if (!deciding) ?delivered,
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
                sub: '${formatMoney(job.budget, job.currency)} held by ${AppBrand.name}',
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

  /// The start proof as the client sees it, with whether it needs them now (then it leads the screen). Null when the
  /// job has none or it is past the working stage.
  (Widget, bool)? _startProofCard(BuildContext context) {
    if (!job.hasStartProof) return null;
    final status = job.contractStatus;
    if (status != ContractStatus.funded && status != ContractStatus.inProgress) return null;
    final amount = formatMoney(job.upfrontAmount ?? job.budget * 0.2, job.currency);
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StartProofScreen(jobId: job.id, forClient: true)));
    switch (job.startProofStatus) {
      case 'submitted':
        final due = job.startProofDueAt;
        return (
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.flag_outlined,
            title: 'The start proof is ready for you',
            body: 'Accept it to pay the talent $amount (20%). If you say nothing it is accepted for you after 24 hours.',
            waiting: due == null ? null : (timeLeft(due) == null ? 'The 24 hours are up' : 'Decide within ${timeLeft(due)}'),
            actions: [KdButton(label: 'Look at it', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: open)],
          ),
          true,
        );
      case 'objected':
        return (
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.fact_check_outlined,
            title: 'A person is checking the start proof',
            body: 'You raised a point. We check it against the format, usually within the day, and tell you both.',
            actions: [KdButton(label: 'See it', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: open)],
          ),
          false,
        );
      case 'redo':
        return (
          NoticeCard(
            tone: KdTone.plain,
            icon: Icons.replay_rounded,
            title: 'The talent is sending the start proof again',
            body: 'We agreed with your point. You\'ll have 24 hours again when it arrives.',
          ),
          false,
        );
      case 'accepted':
        return null;
      default:
        return (
          NoticeCard(
            tone: KdTone.plain,
            icon: Icons.flag_outlined,
            title: 'Waiting for the start proof',
            body: 'The talent will show you they\'ve started. Then you can accept it, which pays them $amount (20%) now.',
          ),
          false,
        );
    }
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
                  'You can cancel for a refund: open "Something\'s wrong" below.',
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
            body: 'Approving sends ${formatMoney(_remaining, job.currency)} to the talent\'s bank account and can\'t be undone.${_paidUpfront ? ' The first ${formatMoney(job.upfrontAmount!, job.currency)} was paid when you accepted the start proof.' : ''} '
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
      case ContractStatus.resolved:
        final back = job.settledClientRefund ?? 0;
        final paid = job.settledTalentAmount ?? 0;
        return [
          NoticeCard(
            tone: KdTone.plain,
            icon: Icons.handshake_outlined,
            title: back > 0 ? 'Settled. ${formatMoney(back, job.currency)} is coming back to you' : 'Settled. The talent was paid in full',
            body: [
              if (back > 0) 'Refunds can take 3 to 10 working days to show in your account. The service fee isn\'t refunded.',
              if (paid > 0) 'The talent was paid ${formatMoney(paid, job.currency)}.',
              if (back > 0 && paid == 0) 'The job has been put back in front of the other people who applied.',
            ].join(' '),
          ),
        ];
      case ContractStatus.approved:
        return [
          NoticeCard(
            tone: KdTone.ok,
            icon: Icons.payments_outlined,
            title: 'You approved. ${formatMoney(job.budget, job.currency)} sent in all',
            body: 'Thanks for paying through ${AppBrand.name}.',
            actions: [KdButton(label: 'Review the talent', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: () => _openReview(context))],
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

  void _openReview(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewScreen(jobId: job.id, jobTitle: job.title)));

  void _openDispute(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DisputeScreen(jobId: job.id, jobTitle: job.title)));

  List<Widget> _actions(BuildContext context, WidgetRef ref, ContractStatus status) {
    if (job.disputeOpen) {
      return [KdButton(label: 'See the open problem', icon: Icons.report_gmailerrorred_outlined, onPressed: () => _openDispute(context))];
    }
    if (status != ContractStatus.submitted) return const [];
    final last = job.changeRounds >= Job.maxChangeRounds;
    return [
      KdButton(label: 'Approve and pay ${formatMoney(_remaining, job.currency)}', onPressed: () { _confirmApprove(context, ref); }),
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
        title: 'Approve and pay ${formatMoney(_remaining, job.currency)}?',
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
              KdToast.show(sheet, 'Approved · ${formatMoney(_remaining, job.currency)} on its way to the talent');
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
