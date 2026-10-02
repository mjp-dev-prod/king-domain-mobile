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
import '../../providers/talent_profile_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../payments/payout_account_screen.dart';
import 'submit_deliverable_screen.dart';

/// The talent's view of a contract (prototypes/stage2-contract-flow.html, left
/// phone): what's due and when, what they asked for, what the client asked
/// for, and the one thing to do next. Stage 2 rules:
/// docs/features/stage-2-delivery-and-changes.md.
class ContractDetailScreen extends ConsumerWidget {
  final String jobId;

  const ContractDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    return Scaffold(
      body: jobsAsync.when(
        loading: () => const _Loading(),
        error: (_, _) => _Message(
          'Couldn\'t load this contract. Check your connection and try again.',
          action: KdButton.secondary(label: 'Try again', onPressed: () => ref.read(jobsProvider.notifier).refresh()),
        ),
        data: (jobs) {
          final job = jobs.where((j) => j.id == jobId).firstOrNull;
          if (job == null || job.contractStatus == null) return const _Message('This job has no contract yet.');
          return LiveClock(builder: (_) => _TalentContract(job: job));
        },
      ),
    );
  }
}

class _TalentContract extends ConsumerWidget {
  final Job job;
  const _TalentContract({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = job.contractStatus!;
    final history = ref.watch(contractHistoryProvider(job.id)).valueOrNull ?? const ContractHistory();
    final needsPayoutAccount = status != ContractStatus.approved &&
        ref.watch(talentProfileProvider).valueOrNull?.payoutAccount == null;
    final held = status == ContractStatus.awaitingPayment ? formatNaira(job.budget) : '${formatNaira(job.budget)} held by ${AppBrand.name}';

    final cards = <Widget>[
      ..._stateCards(context, status, history),
      if (needsPayoutAccount)
        NoticeCard(
          tone: KdTone.brand,
          icon: Icons.account_balance_outlined,
          title: 'Add a payout account',
          body: 'The client can\'t release your payment until you add the bank account it goes to.',
          actions: [
            KdButton(
              label: 'Add bank account',
              variant: KdButtonVariant.soft,
              height: AppDimensions.buttonHeightSm,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutAccountScreen())),
            ),
          ],
        ),
      if (history.deliveries.isNotEmpty)
        VersionsCard(versions: history.deliveries, title: 'What you delivered'),
    ];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(contractHistoryProvider(job.id));
            await ref.read(jobsProvider.notifier).refresh();
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 200),
            children: [
              ContractHeader(title: job.title, sub: '${job.clientName} · $held', pill: contractStatusPill(status)),
              for (var i = 0; i < cards.length; i++)
                Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 60 * i), child: cards[i])),
            ],
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: ActionBar(children: _actions(context, ref, status, history))),
      ],
    );
  }

  List<Widget> _stateCards(BuildContext context, ContractStatus status, ContractHistory history) {
    final client = job.clientName;
    final deadline = job.deliverByAt;
    final deadlineCard = deadline == null
        ? null
        : DeadlineCard(eyebrow: 'Delivery due in', deadline: deadline, start: job.fundedAt, lateNote: 'Deliver now, or ask for more time');

    switch (status) {
      case ContractStatus.awaitingPayment:
        return [
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.hourglass_empty_rounded,
            title: 'Waiting for $client to pay',
            body: '$client selected you. Don\'t start until this contract shows paid.'
                '${job.payByAt == null ? '' : ' They have until ${formatDeadline(job.payByAt!)}; if it isn\'t paid by then the award is cancelled and you\'re back in the running.'}',
          ),
        ];
      case ContractStatus.funded:
        return [
          NoticeCard(
            tone: KdTone.ok,
            icon: Icons.lock_outline_rounded,
            title: 'Payment secured',
            body: '$client paid ${formatNaira(job.budget)} into ${AppBrand.name}. You\'re paid it when they approve your delivery. Start when you\'re ready.',
          ),
          ?deadlineCard,
          ?_extensionCard(history),
        ];
      case ContractStatus.inProgress:
        return [
          ?deadlineCard,
          if (job.overdue)
            const NoticeCard(
              tone: KdTone.bad,
              icon: Icons.error_outline_rounded,
              title: '3 days past the delivery date',
              body: 'Nothing has been delivered and no extension was agreed, and the client has been told. Deliver as soon as you can.',
            ),
          ?_extensionCard(history),
        ];
      case ContractStatus.submitted:
        final rounds = job.changeRoundsLeft;
        return [
          NoticeCard(
            tone: KdTone.brand,
            icon: Icons.schedule_rounded,
            title: 'Waiting for $client to review',
            body: '$client can approve and pay, or ask for changes ($rounds round${rounds == 1 ? '' : 's'} left).'
                '${job.reviewDueAt == null ? '' : ' If they don\'t respond by ${formatDeadline(job.reviewDueAt!)}, you\'re paid automatically.'}',
          ),
        ];
      case ContractStatus.changesRequested:
        final round = history.latestChangeRound;
        final due = job.changeDueAt;
        final last = job.changeRounds >= Job.maxChangeRounds;
        return [
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.edit_outlined,
            title: '$client asked for changes',
            trailing: 'Round ${job.changeRounds} of ${Job.maxChangeRounds}',
            extra: RoundSteps(current: job.changeRounds),
            quote: round?.reason,
            waiting: due == null ? null : switch (timeLeft(due)) { final l? => 'Resubmit within $l', null => 'The resubmit time has run out' },
            footnote: due == null
                ? null
                : 'If you don\'t resubmit by ${formatDeadline(due)}, the job goes to a ${AppBrand.name} admin.${last ? ' This is the last round.' : ''}',
          ),
        ];
      case ContractStatus.disputed:
        return [
          const NoticeCard(
            tone: KdTone.bad,
            icon: Icons.balance_rounded,
            title: 'With a ${AppBrand.name} admin',
            body: 'An admin will look at every version and change request and decide. Nothing is paid out or refunded until then.',
          ),
        ];
      case ContractStatus.approved:
        return [
          NoticeCard(
            tone: KdTone.ok,
            icon: Icons.payments_outlined,
            title: 'You\'ve been paid ${formatNaira(job.budget)}',
            body: 'Sent to your payout account. Transfers can take a little while to show.',
          ),
        ];
    }
  }

  Widget? _extensionCard(ContractHistory history) {
    final e = history.latestExtension;
    if (e == null || e.status == ExtensionStatus.withdrawn) return null;
    final days = '${e.requestedDays} more day${e.requestedDays == 1 ? '' : 's'}';
    return switch (e.status) {
      ExtensionStatus.pending => NoticeCard(
        tone: KdTone.warn,
        icon: Icons.hourglass_top_rounded,
        title: 'You asked for $days',
        quote: e.reason,
        waiting: switch (timeLeft(e.answerDueAt)) { final l? => 'Waiting on ${job.clientName} · $l left to answer', null => 'Being granted now' },
        footnote: 'If ${job.clientName} doesn\'t answer by ${formatDeadline(e.answerDueAt)}, it\'s granted automatically.',
      ),
      ExtensionStatus.declined => NoticeCard(
        tone: KdTone.plain,
        icon: Icons.info_outline_rounded,
        title: 'Extension declined',
        body: job.deliverByAt == null ? null : 'The delivery date stays ${formatDeadline(job.deliverByAt!)}.',
      ),
      _ => NoticeCard(
        tone: KdTone.ok,
        icon: Icons.check_rounded,
        title: e.status == ExtensionStatus.autoGranted ? 'Extension granted automatically' : 'Extension granted',
        body: job.deliverByAt == null ? null : '+$days. The new delivery date is ${formatDeadline(job.deliverByAt!)}.',
      ),
    };
  }

  /// Why the talent can't ask for more time right now, or null if they can.
  String? _extensionBlocked(ContractHistory history) {
    if (job.deliverByAt == null || job.deliveryDays == null) return 'This job has no delivery date';
    if (job.overdue || DateTime.now().isAfter(job.deliverByAt!.add(const Duration(days: 3)))) return 'Too late: 3 days past the date';
    if (history.pendingExtension != null) return 'Waiting on ${job.clientName}\'s answer';
    if (job.extensionRequestsLeft == 0) return 'No extension requests left';
    return null;
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, ContractStatus status, ContractHistory history) {
    final notifier = ref.read(jobsProvider.notifier);
    Widget askForTime() {
      final blocked = _extensionBlocked(history);
      final left = job.extensionRequestsLeft;
      return KdButton.secondary(
        label: blocked ?? 'Ask for more time · $left request${left == 1 ? '' : 's'} left',
        onPressed: blocked == null ? () { _openExtensionSheet(context, ref); } : null,
      );
    }

    void openSubmit() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubmitDeliverableScreen(jobId: job.id)));

    return switch (status) {
      ContractStatus.funded => [
        KdButton(
          label: 'Start work',
          icon: Icons.play_arrow_rounded,
          busyLabel: 'Starting',
          onPressed: () async {
            try {
              await notifier.startWork(job.id);
            } on ApiException catch (e) {
              if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
              throw const ShownError();
            }
          },
        ),
        askForTime(),
      ],
      ContractStatus.inProgress => [
        KdButton(label: 'Deliver the work', icon: Icons.upload_rounded, onPressed: openSubmit),
        askForTime(),
      ],
      ContractStatus.changesRequested => [
        KdButton(label: 'Deliver version ${history.deliveries.length + 1}', icon: Icons.upload_rounded, onPressed: openSubmit),
      ],
      _ => const [],
    };
  }

  Future<void> _openExtensionSheet(BuildContext context, WidgetRef ref) {
    return showKdSheet(context, builder: (_) => _ExtensionSheet(job: job));
  }
}

class _ExtensionSheet extends ConsumerStatefulWidget {
  final Job job;
  const _ExtensionSheet({required this.job});

  @override
  ConsumerState<_ExtensionSheet> createState() => _ExtensionSheetState();
}

class _ExtensionSheetState extends ConsumerState<_ExtensionSheet> {
  final _reason = TextEditingController();
  late int _days = (widget.job.deliveryDays! >= 2) ? 2 : 1;
  bool _valid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final left = job.extensionRequestsLeft;
    return KdSheetBody(
      title: 'Ask for more time',
      lead: '${job.clientName} has 48 hours to answer. If they don\'t, it\'s granted automatically. '
          'You have $left request${left == 1 ? '' : 's'} left on this job, and a declined one counts.',
      children: [
        const SizedBox(height: 16),
        Text('Extra days (up to ${job.deliveryDays}, the job\'s original length)', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DayStepper(value: _days, min: 1, max: job.deliveryDays!, onChanged: (v) => setState(() => _days = v)),
        const SizedBox(height: 14),
        KdCard(
          tone: KdTone.brand,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 18, color: AppColors.primaryText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New date if granted: ${formatDeadline(job.deliverByAt!.add(Duration(days: _days)))}',
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        ReasonField(
          controller: _reason,
          label: 'Why do you need it?',
          hint: 'e.g. The menu photos I need arrived two days late.',
          onValidChanged: (v) => setState(() => _valid = v),
        ),
        const SizedBox(height: 18),
        KdButton(
          label: 'Send request',
          busyLabel: 'Sending',
          onPressed: !_valid
              ? null
              : () async {
                  try {
                    await ref.read(jobsProvider.notifier).requestExtension(job.id, days: _days, reason: _reason.text);
                  } on ApiException catch (e) {
                    if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
                    throw const ShownError();
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  KdToast.show(context, 'Request sent to ${job.clientName}');
                },
        ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
      children: const [
        Skeleton(height: 26, width: 220, radius: 8),
        SizedBox(height: 20),
        SkeletonCard(),
        SizedBox(height: 12),
        SkeletonCard(),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Widget? action;
  const _Message(this.text, {this.action});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
}
