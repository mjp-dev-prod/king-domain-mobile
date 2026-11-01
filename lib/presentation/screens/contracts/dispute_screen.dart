import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/debug_log.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/dispute.dart';
import '../../providers/contract_extras_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import '../profile/address_sheet.dart';

/// "Something's wrong" (PRD §3.3). Most problems end without anyone from ${AppBrand.name} deciding: say what is wrong, see
/// the rule, try a fixed way out (each offer has 48 hours), and only then ask the team, who rule within 5 days, for free,
/// with written reasons. A ruling is final.
class DisputeScreen extends ConsumerWidget {
  final String jobId;
  final String jobTitle;
  const DisputeScreen({super.key, required this.jobId, required this.jobTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(disputeProvider(jobId));
    final job = ref.watch(jobsProvider).valueOrNull?.where((j) => j.id == jobId).firstOrNull;
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: ErrorState(message: 'Couldn\'t load this. Check your connection and try again.', onRetry: () async => ref.invalidate(disputeProvider(jobId))))),
          ]),
        ),
        data: (state) => LiveClock(builder: (_) => _Body(jobId: jobId, jobTitle: jobTitle, state: state, currency: job?.currency ?? 'NGN')),
      ),
    );
  }
}

StatusPill _pill(DisputeState s) {
  final d = s.dispute;
  if (d == null) return const StatusPill('Nothing open', tone: KdTone.plain);
  return switch (d.status) {
    'open' => const StatusPill('Finding a way out', tone: KdTone.warn, pulse: true),
    'escalated' => const StatusPill('With our team', tone: KdTone.brand, pulse: true),
    _ => const StatusPill('Settled', tone: KdTone.ok, icon: Icons.check_rounded),
  };
}

class _Body extends ConsumerWidget {
  final String jobId;
  final String jobTitle;
  final DisputeState state;
  final String currency;
  const _Body({required this.jobId, required this.jobTitle, required this.state, required this.currency});

  String _m(num n) => formatMoney(n, currency);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = state.dispute;
    final cards = <Widget>[
      if (d == null || d.isResolved) ..._idleCards(context, ref) else ..._liveCards(context, ref, d),
      if (d != null && d.isResolved) _ResolvedCard(d: d, state: state, money: _m),
      if (d != null && !state.hasAddress && (d.live)) _addressCard(context),
    ];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(disputeProvider(jobId)),
      child: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
        children: [
          ContractHeader(title: 'Something\'s wrong', sub: '$jobTitle · ${_m(state.held)} held', pill: _pill(state)),
          for (var i = 0; i < cards.length; i++) Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 50 * i), child: cards[i])),
        ],
      ),
    );
  }

  Widget _addressCard(BuildContext context) => NoticeCard(
    tone: KdTone.plain,
    icon: Icons.place_outlined,
    title: 'Tell us where we can reach you',
    body: 'If a ruling can\'t settle something serious, a ${AppBrand.name} agent may need to follow it up in person. It is private and only the team handling the case sees it.',
    actions: [KdButton(label: 'Add my address', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: () => showAddressSheet(context))],
  );

  // ── Nothing open ──

  List<Widget> _idleCards(BuildContext context, WidgetRef ref) {
    return [
      const NoticeCard(
        tone: KdTone.plain,
        icon: Icons.handshake_outlined,
        title: 'Most problems are settled between the two of you',
        body: 'Say what is wrong and you both see the rule that applies. Either of you can offer a way out: more time, one more revision, a split, or to cancel. '
            'The other person has 48 hours to answer. If it can\'t be settled, our team decides within 5 days. It is free, the reasons are written down, and the decision is final.',
      ),
      if (state.heldNote != null) NoticeCard(tone: KdTone.plain, icon: Icons.info_outline_rounded, title: 'What is held', body: '${_m(state.held)} is held. ${state.heldNote}'),
      if (state.canCancelForRefund)
        NoticeCard(
          tone: KdTone.warn,
          icon: Icons.event_busy_outlined,
          title: 'Nothing arrived. You can cancel for a refund',
          body: 'It is more than 3 days past the delivery date with nothing delivered. Cancelling returns the ${_m(state.held)} held to you (the service fee isn\'t refunded), and the job opens again for the other people who applied.',
          actions: [KdButton(label: 'Cancel and refund ${_m(state.held)}', variant: KdButtonVariant.danger, height: AppDimensions.buttonHeightSm, busyLabel: 'Cancelling', onPressed: () => _confirmCancel(context, ref))],
        )
      else if (state.isClient && state.cancelFrom != null && state.cancelFrom!.isAfter(DateTime.now()) && state.canFile)
        NoticeCard(
          tone: KdTone.plain,
          icon: Icons.event_outlined,
          title: 'If nothing arrives',
          body: 'From ${formatDeadline(state.cancelFrom!)}, if nothing has been delivered and no extension is waiting, you can cancel for a refund of the ${_m(state.held)} held.',
        ),
      if (state.canFile) ...[
        Padding(padding: const EdgeInsets.only(left: 4, top: 4), child: Text('What is wrong?', style: AppTextStyles.title)),
        for (final p in state.problems) _ProblemTile(problem: p, onTap: () => _openProblem(context, ref, p)),
      ] else if (state.dispute == null)
        const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'Nothing to report right now', body: 'You can report a problem while the job is being worked on or reviewed.'),
    ];
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) {
    return showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Cancel and refund ${_m(state.held)}?',
        lead: 'This ends the job. The ${_m(state.held)} held comes back to you; refunds can take 3 to 10 working days to show. '
            'The service fee isn\'t refunded${state.heldNote == null ? '' : ', and the first 20% already paid to the talent for the start proof stays theirs'}. This can\'t be undone.',
        children: [
          const SizedBox(height: 16),
          KdButton(
            label: 'Cancel the job',
            variant: KdButtonVariant.danger,
            busyLabel: 'Cancelling',
            onPressed: () async {
              try {
                await ref.read(contractExtrasActionsProvider).cancelForRefund(jobId);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!sheet.mounted) return;
              Navigator.of(sheet).pop();
              KdToast.show(sheet, 'Cancelled. Your refund is on its way');
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep waiting', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  Future<void> _openProblem(BuildContext context, WidgetRef ref, DisputeProblem p) {
    return showKdSheet(context, builder: (_) => _ProblemSheet(jobId: jobId, problem: p));
  }

  // ── Open or with the team ──

  List<Widget> _liveCards(BuildContext context, WidgetRef ref, DisputeView d) {
    final offer = d.pendingOffer;
    final left = d.rulingDueAt == null ? null : timeLeft(d.rulingDueAt!);
    return [
      NoticeCard(
        tone: d.isEscalated ? KdTone.brand : KdTone.warn,
        icon: d.isEscalated ? Icons.balance_rounded : Icons.forum_outlined,
        title: d.isEscalated ? 'With ${AppBrand.name}' : d.problemLabel,
        body: d.isEscalated
            ? (d.awaitingApproval
                ? 'The team has decided and is finalising it. You will see the reasons as soon as it is done.'
                : 'We look at the brief, the conversation, what was delivered and every request, then rule within 5 days. It is free and the decision is final. ${d.escalationReason == 'unanswered' ? 'It came to us because an offer wasn\'t answered in 48 hours.' : d.escalationReason == 'system' ? 'It came to us automatically.' : ''}')
            : 'Nothing moves while this is open: the delivery clock, the review time and automatic payment all wait.',
        quote: d.note.isEmpty ? null : d.note,
        waiting: d.isEscalated ? (left == null ? 'The ruling is due now' : 'Ruling due within $left') : null,
        footnote: d.rule,
      ),
      if (offer != null) _OfferCard(jobId: jobId, offer: offer, money: _m, held: state.held),
      if (offer == null && state.ways.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(left: 4, top: 4), child: Text(d.isEscalated ? 'Still want to settle it yourselves?' : 'Offer a way out', style: AppTextStyles.title)),
        for (final w in state.ways) _WayTile(way: w, onTap: () => showKdSheet(context, builder: (_) => _OfferSheet(jobId: jobId, way: w, state: state, currency: currency))),
      ],
      for (final o in d.offers.where((o) => !o.pending)) _PastOffer(offer: o),
      if (d.isOpen)
        KdButton.secondary(
          label: 'Ask ${AppBrand.name} to decide',
          icon: Icons.balance_rounded,
          onPressed: () => _confirmEscalate(context, ref),
        ),
    ];
  }

  Future<void> _confirmEscalate(BuildContext context, WidgetRef ref) {
    return showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Ask ${AppBrand.name} to decide?',
        lead: 'Our team will look at everything and rule within 5 days. It is free, you will both get the reasons in writing, and the decision is final. Any offer waiting is closed.',
        children: [
          const SizedBox(height: 16),
          KdButton(
            label: 'Yes, ask the team',
            busyLabel: 'Sending',
            onPressed: () async {
              try {
                await ref.read(contractExtrasActionsProvider).askTeamToDecide(jobId);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!sheet.mounted) return;
              Navigator.of(sheet).pop();
              KdToast.show(sheet, 'Sent to our team');
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Not yet', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }
}

class _ProblemTile extends StatelessWidget {
  final DisputeProblem problem;
  final VoidCallback onTap;
  const _ProblemTile({required this.problem, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: problem.label,
      child: KdCard(
        child: Row(children: [
          Expanded(child: Text(problem.label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
        ]),
      ),
    );
  }
}

class _WayTile extends StatelessWidget {
  final DisputeWay way;
  final VoidCallback onTap;
  const _WayTile({required this.way, required this.onTap});

  static String _hint(String kind) => switch (kind) {
    'more_time' => 'Move the date by a few days',
    'extra_revision' => 'One more round of changes',
    'split' => 'Share what is held between you',
    'cancel' => 'End it and return what is held',
    _ => 'Both go back to the job as it was',
  };

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: way.label,
      child: KdCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(way.label, style: AppTextStyles.title),
              Text(_hint(way.kind), style: AppTextStyles.hint),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
        ]),
      ),
    );
  }
}

class _PastOffer extends StatelessWidget {
  final DisputeOffer offer;
  const _PastOffer({required this.offer});

  @override
  Widget build(BuildContext context) {
    final what = switch (offer.status) {
      'declined' => offer.byMe ? 'was declined' : 'you declined',
      'accepted' => 'was accepted',
      _ => 'wasn\'t answered in 48 hours',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text('${offer.byMe ? 'Your offer' : 'Their offer'}: ${offer.description} $what.', style: AppTextStyles.hint),
    );
  }
}

/// The offer waiting for an answer: from the other person (accept or decline) or from you (waiting, with the clock).
class _OfferCard extends ConsumerWidget {
  final String jobId;
  final DisputeOffer offer;
  final String Function(num) money;
  final double held;
  const _OfferCard({required this.jobId, required this.offer, required this.money, required this.held});

  Future<void> _answer(BuildContext context, WidgetRef ref, bool accept) async {
    try {
      await ref.read(contractExtrasActionsProvider).answerOffer(jobId, offer.id, accept: accept);
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    kdLog('dispute', '${accept ? 'accepted' : 'declined'} offer=${offer.id} kind=${offer.kind}');
    if (context.mounted) KdToast.show(context, accept ? 'Accepted' : 'Declined', kind: accept ? ToastKind.ok : ToastKind.info);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = timeLeft(offer.answerDueAt);
    if (offer.byMe) {
      return NoticeCard(
        tone: KdTone.warn,
        icon: Icons.hourglass_top_rounded,
        title: 'Your offer: ${offer.description}',
        quote: offer.note.isEmpty ? null : offer.note,
        waiting: left == null ? 'Their time to answer has run out' : 'Waiting for their answer · $left left',
        footnote: 'If they don\'t answer in 48 hours it goes to the ${AppBrand.name} team to decide.',
      );
    }
    return NoticeCard(
      tone: KdTone.brand,
      icon: Icons.local_offer_outlined,
      title: 'They offer: ${offer.description}',
      quote: offer.note.isEmpty ? null : offer.note,
      body: offer.kind == 'split' || offer.kind == 'cancel' ? 'Accepting settles it now: the money moves at once and the job ends.' : 'Accepting settles it now and the job carries on.',
      waiting: left == null ? 'Your time to answer has run out' : 'Answer within $left',
      footnote: 'If you don\'t answer in 48 hours it goes to the ${AppBrand.name} team to decide.',
      actions: [
        KdButton(label: 'Decline', variant: KdButtonVariant.secondary, height: AppDimensions.buttonHeightSm, busyLabel: 'Declining', onPressed: () => _answer(context, ref, false)),
        KdButton(label: 'Accept', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, busyLabel: 'Accepting', onPressed: () => _answer(context, ref, true)),
      ],
    );
  }
}

class _ResolvedCard extends StatelessWidget {
  final DisputeView d;
  final DisputeState state;
  final String Function(num) money;
  const _ResolvedCard({required this.d, required this.state, required this.money});

  @override
  Widget build(BuildContext context) {
    final r = d.ruling;
    if (r != null) {
      final what = r.outcome == 'release' ? 'Released to the talent' : r.outcome == 'refund' ? 'Refunded to the client' : '${r.talentPercent}% to the talent';
      return NoticeCard(
        tone: KdTone.ok,
        icon: Icons.balance_rounded,
        title: 'Ruled: $what',
        body: '${money(r.talentAmount)} to the talent, ${money(r.clientRefund)} back to the client. This decision is final.',
        quote: r.reasons,
        footnote: state.isClient && r.clientRefund > 0 ? 'Refunds can take 3 to 10 working days to show in your account.' : null,
      );
    }
    final kind = d.resolution?['kind'] as String?;
    return NoticeCard(
      tone: KdTone.ok,
      icon: Icons.handshake_outlined,
      title: 'Settled between you',
      body: switch (kind) {
        'more_time' => 'You agreed more time, and the job carries on.',
        'extra_revision' => 'You agreed one more revision, and the job carries on.',
        'split' => 'You agreed a split, and the money has moved.',
        'cancel' => 'You agreed to cancel, and what was held is going back to the client.',
        _ => 'You agreed to carry on, and the clocks started again.',
      },
    );
  }
}

/// Pick what is wrong and say what happened. The rule that applies is shown first.
class _ProblemSheet extends ConsumerStatefulWidget {
  final String jobId;
  final DisputeProblem problem;
  const _ProblemSheet({required this.jobId, required this.problem});

  @override
  ConsumerState<_ProblemSheet> createState() => _ProblemSheetState();
}

class _ProblemSheetState extends ConsumerState<_ProblemSheet> {
  final _note = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: widget.problem.label,
      lead: widget.problem.rule,
      children: [
        ReasonField(
          controller: _note,
          label: 'What happened?',
          hint: 'Be specific: what, when, and what you expected.',
          onValidChanged: (v) => setState(() => _valid = v),
        ),
        const SizedBox(height: 6),
        Text('The other person is told, and nothing moves while this is open. You can offer a way out next.', style: AppTextStyles.hint),
        const SizedBox(height: 16),
        KdButton(
          label: 'Report it',
          busyLabel: 'Sending',
          onPressed: !_valid
              ? null
              : () async {
                  try {
                    await ref.read(contractExtrasActionsProvider).openDispute(widget.jobId, problem: widget.problem.code, note: _note.text.trim());
                  } on ApiException catch (e) {
                    if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
                    throw const ShownError();
                  }
                  kdLog('dispute', 'opened job=${widget.jobId} problem=${widget.problem.code}');
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  KdToast.show(context, 'Reported. The other person has been told', kind: ToastKind.info);
                },
        ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// Offer a fixed way out, with the numbers it needs.
class _OfferSheet extends ConsumerStatefulWidget {
  final String jobId;
  final DisputeWay way;
  final DisputeState state;
  final String currency;
  const _OfferSheet({required this.jobId, required this.way, required this.state, required this.currency});

  @override
  ConsumerState<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<_OfferSheet> {
  int _days = 2;
  double _pct = 50;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _m(num n) => formatMoney(n, widget.currency);

  @override
  Widget build(BuildContext context) {
    final w = widget.way;
    final held = widget.state.held;
    final talent = (held * _pct / 100 * 100).round() / 100;
    return KdSheetBody(
      title: w.label,
      lead: switch (w.kind) {
        'more_time' => 'Move the date, or the time to resubmit, by a few days.',
        'extra_revision' => 'Add one more round of changes. The clocks start again.',
        'split' => 'Share the ${_m(held)} held. The service fee isn\'t part of it.',
        'cancel' => 'End the job and return the ${_m(held)} held to the client. The job opens again for the other people who applied.',
        _ => 'Go back to the job as it was. The clocks start again.',
      },
      children: [
        if (w.kind == 'more_time') ...[
          const SizedBox(height: 14),
          DayStepper(value: _days, min: 1, max: widget.state.maxMoreDays, onChanged: (v) => setState(() => _days = v)),
        ],
        if (w.kind == 'split') ...[
          const SizedBox(height: 14),
          Text('The talent gets ${_pct.round()}%', style: AppTextStyles.title),
          Slider(value: _pct, min: 0, max: 100, divisions: 20, label: '${_pct.round()}%', onChanged: (v) => setState(() => _pct = v)),
          Row(children: [
            Expanded(child: Text('Talent ${_m(talent)}', style: AppTextStyles.bodySmall)),
            Text('Client ${_m(held - talent)}', style: AppTextStyles.bodySmall),
          ]),
        ],
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 500, maxLines: 2, decoration: const InputDecoration(hintText: 'A line to go with it (optional)')),
        const SizedBox(height: 6),
        Text('They have 48 hours to answer. If they don\'t, it goes to the ${AppBrand.name} team.', style: AppTextStyles.hint),
        const SizedBox(height: 14),
        KdButton(
          label: 'Send the offer',
          busyLabel: 'Sending',
          onPressed: () async {
            try {
              await ref.read(contractExtrasActionsProvider).offerWayOut(
                widget.jobId,
                kind: w.kind,
                params: switch (w.kind) {
                  'more_time' => {'days': _days},
                  'split' => {'talentPercent': _pct.round()},
                  _ => null,
                },
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              );
            } on ApiException catch (e) {
              if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
              throw const ShownError();
            }
            kdLog('dispute', 'offered job=${widget.jobId} kind=${w.kind}');
            if (!context.mounted) return;
            Navigator.of(context).pop();
            KdToast.show(context, 'Offer sent');
          },
        ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
