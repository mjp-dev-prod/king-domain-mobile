import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/reputation.dart';
import '../../providers/reputation_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/reputation_widgets.dart';
import '../../widgets/kit/status_pill.dart';

/// Reviewing the other person after a job (PRD §4.8; D29 to D31). No stars: specific questions, a recommendation, a
/// comment. Nobody sees the other's review until both are in, or 14 days pass, and then neither can be changed.
/// One extra question is private: only ${AppBrand.name} ever sees it.
class ReviewScreen extends ConsumerWidget {
  final String jobId;
  final String jobTitle;
  const ReviewScreen({super.key, required this.jobId, required this.jobTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewProvider(jobId));
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: ErrorState(message: 'Couldn\'t load this. Check your connection and try again.', onRetry: () async => ref.invalidate(reviewProvider(jobId))))),
          ]),
        ),
        data: (s) => _Body(jobId: jobId, jobTitle: jobTitle, state: s),
      ),
    );
  }
}

StatusPill _pill(ReviewState s) => switch (s.state) {
  'can_review' => StatusPill(s.daysLeft <= 3 ? '${s.daysLeft} day${s.daysLeft == 1 ? '' : 's'} left' : 'Open', tone: KdTone.brand),
  'waiting' => const StatusPill('Waiting for theirs', tone: KdTone.warn),
  'revealed' => const StatusPill('Reviews are in', tone: KdTone.ok, icon: Icons.check_rounded),
  'window_closed' => const StatusPill('Closed', tone: KdTone.plain),
  _ => const StatusPill('Not yet', tone: KdTone.plain),
};

class _Body extends ConsumerStatefulWidget {
  final String jobId;
  final String jobTitle;
  final ReviewState state;
  const _Body({required this.jobId, required this.jobTitle, required this.state});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final Map<String, dynamic> _answers = {};
  bool? _privateAgain;
  final _comment = TextEditingController();
  bool _editing = false;
  bool _seeded = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _seedFromMine() {
    final mine = widget.state.mine;
    if (mine == null || _seeded) return;
    _seeded = true;
    _answers
      ..clear()
      ..addAll(mine.answers);
    _privateAgain = mine.privateAgain;
    _comment.text = mine.comment;
  }

  bool get _complete => widget.state.questions.every((q) => _answers[q.key] != null) && _privateAgain != null;

  Future<void> _send() async {
    try {
      await ref.read(reviewActionsProvider).submit(widget.jobId, answers: Map.of(_answers), comment: _comment.text.trim(), privateAgain: _privateAgain!);
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (!mounted) return;
    setState(() => _editing = false);
    KdToast.show(context, 'Sent. You\'ll see theirs when they\'ve written theirs');
  }

  Future<void> _reply() async {
    final text = await showKdSheet<String>(context, builder: (_) => const _ReplySheet());
    if (text == null) return;
    try {
      await ref.read(reviewActionsProvider).reply(widget.jobId, text);
      if (mounted) KdToast.show(context, 'Replied');
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cards = <Widget>[];
    final other = s.otherName ?? (s.isClient ? 'the talent' : 'the client');

    if (s.state == 'not_yet') {
      cards.add(EmptyState(icon: Icons.hourglass_empty_rounded, title: 'Not yet', body: s.message ?? 'You can review once the job has been paid out.'));
    } else {
      if (s.facts != null) {
        cards.add(NoticeCard(tone: KdTone.plain, icon: Icons.fact_check_outlined, title: 'What we recorded', body: s.facts!.lines.join('\n'), footnote: 'These come from the job\'s own dates. They can\'t be argued with, so your review is for the rest.'));
      }
      if ((s.state == 'can_review' || (s.state == 'waiting' && _editing))) {
        _seedFromMine();
        cards.add(_form(s, other));
      } else if (s.state == 'waiting') {
        cards.add(_mineView(s, canEdit: s.canEdit));
        cards.add(NoticeCard(
          tone: KdTone.warn,
          icon: Icons.lock_clock_outlined,
          title: 'Theirs is hidden for now',
          body: s.theirsExists
              ? '$other has written theirs. You\'ll both see them at the same time, so neither is shaped by the other.'
              : 'You\'ll both see them at the same time, as soon as $other has written theirs, or on ${s.windowEndsAt == null ? 'the last day' : formatDeadline(s.windowEndsAt!).split(',').first}.',
        ));
      } else if (s.state == 'revealed' || s.state == 'window_closed') {
        if (s.mine != null) cards.add(_mineView(s, canEdit: false));
        if (s.state == 'window_closed' && s.mine == null) {
          cards.add(const NoticeCard(tone: KdTone.plain, icon: Icons.event_busy_outlined, title: 'The 14 days passed', body: 'Reviews close 14 days after a job is paid out, so they stay honest and fresh.'));
        }
        if (s.theirs != null) cards.add(_theirsView(s, other));
        if (s.canReply) cards.add(KdButton.secondary(label: 'Reply to what $other wrote', icon: Icons.reply_rounded, onPressed: _reply));
      }
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(reviewProvider(widget.jobId)),
      child: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
        children: [
          ContractHeader(title: 'How did it go?', sub: widget.jobTitle, pill: _pill(s)),
          for (var i = 0; i < cards.length; i++) Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 50 * i), child: cards[i])),
        ],
      ),
    );
  }

  // ── The form ──

  Widget _form(ReviewState s, String other) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (s.theirsExists && s.state == 'can_review')
        const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('They\'ve already written theirs. You\'ll see it as soon as you send yours.', style: TextStyle(color: AppColors.text2))),
      for (final q in s.questions) ...[
        KdCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.label, style: AppTextStyles.title),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (q.kind == 'triple') ...[
                for (final v in const ['yes', 'partly', 'no']) KdChoiceChip(label: v[0].toUpperCase() + v.substring(1), selected: _answers[q.key] == v, onTap: () => setState(() => _answers[q.key] = v)),
              ] else ...[
                KdChoiceChip(label: 'Yes', selected: _answers[q.key] == true, onTap: () => setState(() => _answers[q.key] = true)),
                KdChoiceChip(label: 'No', selected: _answers[q.key] == false, onTap: () => setState(() => _answers[q.key] = false)),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      KdCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('In your own words (optional)', style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text('What did $other do well, and what could be better? Specifics help the next person.', style: AppTextStyles.hint),
          const SizedBox(height: 8),
          TextField(controller: _comment, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(hintText: 'e.g. Sent the drafts early and fixed my notes the same day.')),
        ]),
      ),
      const SizedBox(height: 10),
      KdCard(
        tone: KdTone.brand,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primaryText), const SizedBox(width: 8), Text('Private', style: AppTextStyles.title)]),
          const SizedBox(height: 6),
          Text(s.privateQuestion, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 4),
          Text('Never shown to them or anyone else. It helps us keep the platform honest.', style: AppTextStyles.hint),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            KdChoiceChip(label: 'Yes', selected: _privateAgain == true, onTap: () => setState(() => _privateAgain = true)),
            KdChoiceChip(label: 'No', selected: _privateAgain == false, onTap: () => setState(() => _privateAgain = false)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      KdButton(label: _editing ? 'Save changes' : 'Send my review', busyLabel: 'Sending', onPressed: _complete ? _send : null),
      if (!_complete) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Answer every question to send it.', textAlign: TextAlign.center, style: AppTextStyles.hint)),
      const SizedBox(height: 4),
      Text('You can change it until both reviews are in. After that it is locked.', textAlign: TextAlign.center, style: AppTextStyles.hint),
    ]);
  }

  // ── Showing reviews ──

  Widget _mineView(ReviewState s, {required bool canEdit}) {
    final m = s.mine!;
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your review', style: AppTextStyles.title),
        const SizedBox(height: 8),
        _answerPills(m.answers),
        if (m.comment.isNotEmpty) ...[const SizedBox(height: 10), Text('"${m.comment}"', style: AppTextStyles.bodyMedium)],
        if (m.reply != null) ...[const SizedBox(height: 10), Text('Their reply: ${m.reply}', style: AppTextStyles.bodySmall)],
        if (canEdit) ...[
          const SizedBox(height: 12),
          KdButton.secondary(label: 'Change my review', height: AppDimensions.buttonHeightSm, onPressed: () => setState(() {
            _seeded = false;
            _seedFromMine();
            _editing = true;
          })),
        ],
      ]),
    );
  }

  Widget _theirsView(ReviewState s, String other) {
    final t = s.theirs!;
    return KdCard(
      tone: KdTone.ok,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What $other wrote', style: AppTextStyles.title),
        const SizedBox(height: 8),
        _answerPills(t.answers),
        if (t.comment.isNotEmpty) ...[const SizedBox(height: 10), Text('"${t.comment}"', style: AppTextStyles.bodyMedium.copyWith(height: 1.45))],
        if (t.reply != null) ...[const SizedBox(height: 10), Text('Your reply: ${t.reply}', style: AppTextStyles.bodySmall)],
      ]),
    );
  }

  Widget _answerPills(Map<String, dynamic> answers) => Wrap(spacing: 6, runSpacing: 6, children: [
    for (final e in answers.entries) StatusPill('${answerLabel(e.key)}: ${answerText(e.value)}', tone: answerTone(e.value)),
  ]);
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet();

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _text.text.trim().length >= 5;
    return KdSheetBody(
      title: 'Reply publicly',
      lead: 'One reply, shown under their review. Keep it about the work. You can\'t edit it after.',
      children: [
        const SizedBox(height: 12),
        TextField(controller: _text, maxLines: 4, maxLength: 500, autofocus: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Thank them, correct a fact, or say what you changed.')),
        const SizedBox(height: 12),
        KdButton(label: 'Post reply', onPressed: ok ? () => Navigator.of(context).pop(_text.text.trim()) : null),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
