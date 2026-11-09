import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/skill_submission.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_stepper.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import 'file_section.dart';
import 'piece_editor_screen.dart';
import 'sent_work_screen.dart';
import 'skill_history.dart';

/// How long we aim to take, from sending to a result: the authenticity check (24 h target) plus the review
/// (72 h target), rounded up. Provisional until real handling times exist (admin inbox shows them).
const replyDays = 4;

void _push(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

/// One attempt at proving a skill. Which screen it is depends on where the attempt is: a draft being built,
/// work waiting on people, or a result (PRD §4.3, decisions D5 to D9).
class SubmissionScreen extends ConsumerWidget {
  final String submissionId;
  const SubmissionScreen({super.key, required this.submissionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(submissionProvider(submissionId));
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load this. Check your connection and try again.", onRetry: () async => ref.invalidate(submissionProvider(submissionId)))),
        data: (d) => switch (d.status) {
          SubmissionStatus.draft => _Builder(detail: d),
          SubmissionStatus.authenticity || SubmissionStatus.review => _Waiting(detail: d),
          _ => _ResultView(detail: d),
        },
      ),
    );
  }
}

EdgeInsets _pagePadding(BuildContext context) => EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40);

// ── Draft ────────────────────────────────────────────────

class _Builder extends ConsumerStatefulWidget {
  final SubmissionDetail detail;
  const _Builder({required this.detail});

  @override
  ConsumerState<_Builder> createState() => _BuilderState();
}

class _BuilderState extends ConsumerState<_Builder> {
  late final _aiNote = TextEditingController(text: widget.detail.aiNote ?? '');

  @override
  void dispose() {
    _aiNote.dispose();
    super.dispose();
  }

  SubmissionActions get _actions => ref.read(submissionActionsProvider);

  Future<void> _declare({bool? ownWork, bool? aiUsed, String? aiNote, bool? acceptTerms}) async {
    try {
      await _actions.updateDeclaration(widget.detail.id, ownWork: ownWork, aiUsed: aiUsed, aiNote: aiNote, acceptTerms: acceptTerms);
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _addPiece() async {
    try {
      await _actions.addPiece(widget.detail.id);
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      return;
    }
    final fresh = await ref.read(submissionProvider(widget.detail.id).future);
    if (!mounted || fresh.pieces.isEmpty) return;
    _push(context, PieceEditorScreen(submissionId: fresh.id, pieceId: fresh.pieces.last.id));
  }

  Future<void> _discard() async {
    final sure = await showKdSheet<bool>(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Throw this draft away?',
        lead: 'Everything you added is deleted. It will not count as an attempt.',
        children: [
          const SizedBox(height: 12),
          KdButton(label: 'Throw it away', onPressed: () => Navigator.of(sheet).pop(true)),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep working', onPressed: () => Navigator.of(sheet).pop(false)),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _actions.discard(widget.detail.id);
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _send() async {
    final d = widget.detail;
    if (d.aiUsed && _aiNote.text.trim() != (d.aiNote ?? '')) await _declare(aiNote: _aiNote.text.trim());
    final fresh = await ref.read(submissionProvider(d.id).future);
    if (!fresh.ready) {
      final missing = fresh.readiness.where((i) => !i.done).map((i) => i.label).toList();
      if (mounted) KdToast.show(context, 'Still to do: ${missing.first}${missing.length > 1 ? ' (and ${missing.length - 1} more)' : ''}', kind: ToastKind.error);
      throw const ShownError();
    }
    if (!mounted) return;
    final go = await showKdSheet<bool>(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Send it for checking?',
        lead: 'After you send it, you can\'t change it. A person checks the work is yours, then two reviewers judge it. You will usually hear back within $replyDays days.',
        children: [
          const SizedBox(height: 12),
          KdButton(label: 'Send it', onPressed: () => Navigator.of(sheet).pop(true)),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Not yet', onPressed: () => Navigator.of(sheet).pop(false)),
        ],
      ),
    );
    if (go != true) throw const ShownError();
    try {
      await _actions.submit(d.id);
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (mounted) KdToast.show(context, 'Sent. We will tell you when there is a result.');
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final done = d.readiness.where((i) => i.done).length;
    return ListView(
      padding: _pagePadding(context),
      children: [
        ContractHeader(title: d.skillLabel, sub: 'Your draft. Nothing is sent until you tap Send.', pill: StatusPill('$done of ${d.readiness.length} ready', tone: d.ready ? KdTone.ok : KdTone.brand)),
        const SizedBox(height: 16),
        RiseIn(child: _Checklist(detail: d)),
        const SizedBox(height: 12),
        _Rubric(detail: d),
        const SizedBox(height: 20),
        Text('Your pieces of work', style: AppTextStyles.title),
        const SizedBox(height: 4),
        Text('Send ${d.minPieces} or ${d.maxPieces} pieces you made yourself. Work you did for real people is best.', style: AppTextStyles.hint),
        const SizedBox(height: 10),
        for (final p in d.pieces) ...[_PieceCard(detail: d, piece: p), const SizedBox(height: 10)],
        if (d.pieces.length < d.maxPieces) KdButton.secondary(label: d.pieces.isEmpty ? 'Add your first piece' : 'Add another piece', icon: Icons.add_rounded, onPressed: _addPiece),
        const SizedBox(height: 20),
        Text('Walkthrough', style: AppTextStyles.title),
        const SizedBox(height: 10),
        FileSection(
          submissionId: d.id,
          detail: d,
          role: FileRole.walkthrough,
          files: d.walkthrough,
          single: true,
          title: 'A 2 to 3 minute video',
          hint: 'Show your work and explain how you made it, in your own voice. This is how reviewers know it is yours.',
        ),
        const SizedBox(height: 20),
        Text('Your declaration', style: AppTextStyles.title),
        const SizedBox(height: 10),
        KdCard(
          child: Column(children: [
            _SwitchRow(
              label: 'This is my own work, or I have said which part I made',
              value: d.declaredOwnWork,
              onChanged: (v) => _declare(ownWork: v),
            ),
            const Divider(),
            _SwitchRow(label: 'I used AI tools for part of it', value: d.aiUsed, onChanged: (v) => _declare(aiUsed: v)),
            if (d.aiUsed) ...[
              const SizedBox(height: 10),
              Focus(
                onFocusChange: (has) {
                  if (!has && _aiNote.text.trim() != (d.aiNote ?? '')) _declare(aiNote: _aiNote.text.trim());
                },
                child: KdTextField(controller: _aiNote, label: 'Which tools, and for what part', maxLines: 3),
              ),
            ],
          ]),
        ),
        if (d.termsNeeded) ...[
          const SizedBox(height: 12),
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.gavel_rounded,
            title: 'Before you send again',
            extra: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in d.terms) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $t', style: AppTextStyles.bodySmall)),
                const SizedBox(height: 4),
                _SwitchRow(label: 'I have read and accept these terms', value: d.termsAccepted, onChanged: (v) => _declare(acceptTerms: v)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        KdButton(label: 'Send for checking', busyLabel: 'Sending', onPressed: _send),
        const SizedBox(height: 6),
        Center(child: AuthLink(lead: '', action: 'Throw this draft away', onTap: _discard)),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
      const SizedBox(width: 8),
      Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.primary),
    ]);
  }
}

class _Checklist extends StatelessWidget {
  final SubmissionDetail detail;
  const _Checklist({required this.detail});

  @override
  Widget build(BuildContext context) {
    if (detail.ready) {
      return const NoticeCard(tone: KdTone.ok, icon: Icons.check_circle_outline_rounded, title: 'Ready to send', body: 'Everything is there. Look it over once more, then send it.');
    }
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Before you can send', style: AppTextStyles.title),
          const SizedBox(height: 10),
          for (final i in detail.readiness)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(i.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: i.done ? AppColors.ok : AppColors.text3),
                const SizedBox(width: 10),
                Expanded(child: Text(i.label, style: AppTextStyles.bodyMedium.copyWith(color: i.done ? AppColors.text3 : AppColors.text))),
              ]),
            ),
        ],
      ),
    );
  }
}

/// What the reviewers score, so the person knows the standard before sending (D5).
class _Rubric extends StatelessWidget {
  final SubmissionDetail detail;
  const _Rubric({required this.detail});

  @override
  Widget build(BuildContext context) {
    if (detail.rubric.isEmpty) return const SizedBox.shrink();
    return KdCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text('What the reviewers look for', style: AppTextStyles.title),
          subtitle: Text('Reviewers rate ${detail.rubric.length} things, 1 to 4 each', style: AppTextStyles.hint),
          children: [
            for (final l in detail.rubric)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  Text(l.looksLike, style: AppTextStyles.bodySmall),
                ]),
              ),
            if (detail.rubricDraft)
              Text('This list is a first draft. We are still refining it with people who do this work every day.', style: AppTextStyles.hint),
          ],
        ),
      ),
    );
  }
}

class _PieceCard extends StatelessWidget {
  final SubmissionDetail detail;
  final SubmissionPiece piece;
  const _PieceCard({required this.detail, required this.piece});

  @override
  Widget build(BuildContext context) {
    int n(FileRole r) => piece.filesOf(r).where((f) => f.ready).length;
    final madeFiles = n(FileRole.working) + n(FileRole.draft);
    final summary = '${n(FileRole.output)} finished · ${madeFiles + (piece.processLink.trim().isEmpty ? 0 : 1)} showing how it was made';
    return Pressable(
      onTap: () => _push(context, PieceEditorScreen(submissionId: detail.id, pieceId: piece.id)),
      semanticLabel: 'Edit ${piece.displayTitle}',
      child: KdCard(
        tone: piece.detailsDone && (n(FileRole.output) > 0 || piece.liveLink.trim().isNotEmpty) ? KdTone.ok : KdTone.plain,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${piece.position}. ${piece.displayTitle}', style: AppTextStyles.title),
              const SizedBox(height: 2),
              Text(piece.detailsDone ? summary : 'Add the details and files', style: AppTextStyles.hint.copyWith(color: piece.detailsDone ? AppColors.text3 : AppColors.warn)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
        ]),
      ),
    );
  }
}

// ── Waiting on people ────────────────────────────────────

class _Waiting extends StatelessWidget {
  final SubmissionDetail detail;
  const _Waiting({required this.detail});

  @override
  Widget build(BuildContext context) {
    final inReview = detail.status == SubmissionStatus.review;
    final sent = detail.submittedAt;
    return ListView(
      padding: _pagePadding(context),
      children: [
        ContractHeader(
          title: detail.skillLabel,
          sub: sent == null ? 'Sent for checking.' : 'Sent ${formatAgo(sent)}.',
          pill: StatusPill(inReview ? 'With reviewers' : 'Being checked', tone: KdTone.warn, pulse: true),
        ),
        const SizedBox(height: 16),
        RiseIn(
          child: NoticeCard(
            tone: KdTone.warn,
            icon: Icons.hourglass_top_rounded,
            title: inReview ? 'Two reviewers are judging it' : 'A person is checking it is yours',
            body: inReview
                ? 'Two reviewers rate it on the list you saw. They do not know who you are, and they do not see each other\'s answers. If they disagree, a third reviewer decides.'
                : 'A person watches your walkthrough and looks at how you made it, to be sure it is your work. Then it goes to two reviewers.',
            footnote: 'You will usually hear back within $replyDays days, by notification and email. There is nothing you need to do.',
          ),
        ),
        const SizedBox(height: 16),
        KdCard(
          child: KdStepper(
            steps: [
              KdStep(label: 'Sent', state: KdStepState.done, subtitle: sent == null ? null : formatDeadline(sent)),
              KdStep(label: 'Checked that it is yours', state: inReview ? KdStepState.done : KdStepState.waiting, subtitle: inReview ? null : 'A person is on it'),
              KdStep(label: 'Scored by two reviewers', state: inReview ? KdStepState.waiting : KdStepState.later),
              const KdStep(label: 'Your result, with reasons', state: KdStepState.later),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Your work', style: AppTextStyles.title),
        const SizedBox(height: 8),
        ListGroup(
          rows: [
            for (final p in detail.pieces)
              ListRow(
                icon: Icons.folder_outlined,
                title: p.displayTitle,
                sub: _pieceSub(p),
                onTap: () => openSentWork(context, detail.id, focusPieceId: p.id),
              ),
            ListRow(
              icon: Icons.videocam_outlined,
              title: 'Walkthrough',
              sub: detail.hasWalkthrough ? detail.walkthrough.first.name : 'None',
              onTap: () => openSentWork(context, detail.id),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SeeEverythingButton(submissionId: detail.id),
        const SizedBox(height: 20),
        SkillHistory(skillKey: detail.skillKey, exceptId: detail.id),
      ],
    );
  }
}

String _pieceSub(SubmissionPiece p) {
  final files = p.files.where((f) => f.ready).length;
  return [
    '$files ${files == 1 ? 'file' : 'files'}',
    if (p.liveLink.isNotEmpty) 'live link',
    if (p.processLink.isNotEmpty) 'how-it-was-made link',
  ].join(' · ');
}

// ── Result ───────────────────────────────────────────────

String scoreText(int score) => switch (score) {
  1 => 'Below the standard',
  2 => 'Nearly there',
  3 => 'Meets the standard',
  _ => 'Strong',
};

class _ResultView extends ConsumerWidget {
  final SubmissionDetail detail;
  const _ResultView({required this.detail});

  Future<void> _again(BuildContext context, WidgetRef ref) async {
    try {
      final next = await ref.read(submissionActionsProvider).startOrContinue(detail.skillKey);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SubmissionScreen(submissionId: next.id)));
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = detail.result;
    final decided = detail.decidedAt;
    final children = <Widget>[];
    StatusPill pill;

    if (detail.status == SubmissionStatus.verified) {
      pill = const StatusPill('Verified', tone: KdTone.ok, icon: Icons.check_rounded);
      children.add(NoticeCard(
        tone: KdTone.ok,
        icon: Icons.verified_rounded,
        title: 'You are verified in ${detail.skillLabel}',
        body: 'Two reviewers looked at your work and agreed it is good. You can now apply to ${detail.skillLabel} jobs, and clients can see that you are verified.',
        actions: [KdButton(label: 'Done', height: AppDimensions.buttonHeightSm, onPressed: () => Navigator.of(context).pop())],
      ));
    } else if (detail.status == SubmissionStatus.removed) {
      pill = const StatusPill('Not allowed', tone: KdTone.bad);
      children.add(NoticeCard(
        tone: KdTone.bad,
        icon: Icons.block_rounded,
        title: "You can't submit in ${detail.skillLabel}",
        body: 'We found that this work was not yours, so you cannot be verified in this skill.',
        quote: r?.note,
        footnote: 'If you think we got this wrong, contact support from your profile and we will look again.',
      ));
    } else if (r?.kind == 'authenticity') {
      final until = r?.restrictedUntil;
      pill = StatusPill(until != null ? 'Paused' : 'Not yet', tone: until != null ? KdTone.bad : KdTone.warn);
      children.add(NoticeCard(
        tone: until != null ? KdTone.bad : KdTone.warn,
        icon: until != null ? Icons.pause_circle_outline_rounded : Icons.refresh_rounded,
        title: until != null ? "You can't submit until ${formatDeadline(until).split(',').first}" : "We could not tell yet that this is your work",
        body: until != null
            ? 'You sent the same work again after it was turned down, without changing it. So you are locked out of this skill for now.'
            : 'It did not go to the reviewers, and nothing counts against you. Fix what is listed below and send it again.',
        quote: r?.note,
        actions: until != null ? const [] : [KdButton(label: 'Fix it and send again', height: AppDimensions.buttonHeightSm, busyLabel: 'Opening', onPressed: () => _again(context, ref))],
      ));
    } else {
      pill = const StatusPill('Not yet', tone: KdTone.warn);
      children.add(NoticeCard(
        tone: KdTone.warn,
        icon: Icons.refresh_rounded,
        title: 'Not yet',
        body: 'Two reviewers rated your work. It is not a no for good. Fix what is listed and send it again.',
        footnote: 'Change the work before you send it again. Sending the same files again locks you out of this skill for 2 months, then 3.',
        actions: [KdButton(label: 'Fix it and send again', height: AppDimensions.buttonHeightSm, busyLabel: 'Opening', onPressed: () => _again(context, ref))],
      ));
      if ((r?.lines ?? const []).isNotEmpty) {
        children
          ..add(const SizedBox(height: 16))
          ..add(Text('What fell short', style: AppTextStyles.title))
          ..add(const SizedBox(height: 8));
        for (final l in r!.lines) {
          children
            ..add(KdCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(l.label, style: AppTextStyles.title)),
                  Text(scoreText(l.score), style: AppTextStyles.bodySmall.copyWith(color: AppColors.warn, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text('What good looks like: ${l.looksLike}', style: AppTextStyles.bodySmall),
              ]),
            ))
            ..add(const SizedBox(height: 8));
        }
      }
      if ((r?.comments ?? const []).isNotEmpty) {
        children
          ..add(const SizedBox(height: 8))
          ..add(Text('In the reviewers\' words', style: AppTextStyles.title))
          ..add(const SizedBox(height: 8));
        for (final c in r!.comments) {
          children
            ..add(KdCard(child: Text('“$c”', style: AppTextStyles.bodyMedium)))
            ..add(const SizedBox(height: 8));
        }
        children.add(Text('You never see who the reviewers were, and they never saw who you were.', style: AppTextStyles.hint));
      }
    }

    return ListView(
      padding: _pagePadding(context),
      children: [
        ContractHeader(title: detail.skillLabel, sub: decided == null ? 'Result' : 'Decided ${formatAgo(decided)}', pill: pill),
        const SizedBox(height: 16),
        RiseIn(child: children.first),
        ...children.skip(1),
        const SizedBox(height: 16),
        SeeEverythingButton(submissionId: detail.id),
        const SizedBox(height: 20),
        SkillHistory(skillKey: detail.skillKey, exceptId: detail.id),
      ],
    );
  }
}
