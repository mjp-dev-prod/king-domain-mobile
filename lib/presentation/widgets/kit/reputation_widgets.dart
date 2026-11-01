import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/reputation.dart';
import '../../providers/reputation_provider.dart';
import 'kd_button.dart';
import 'kd_card.dart';
import 'kd_toast.dart';
import 'pressable.dart';
import 'reason_sheet.dart';
import 'status_pill.dart';

/// The short names of the questions, for showing an answer next to a review.
const _answerLabels = {
  'followedBrief': 'Followed the brief',
  'qualityAsAgreed': 'Quality as agreed',
  'communicated': 'Communicated well',
  'briefClear': 'Brief was clear',
  'feedbackClear': 'Feedback clear and on time',
  'paidFairly': 'Paid and approved fairly',
  'recommend': 'Would recommend',
};

/// The short name of a question key, for showing an answer.
String answerLabel(String key) => _answerLabels[key] ?? key;

String answerText(Object? v) => v is bool ? (v ? 'yes' : 'no') : '$v';

String _answerText(Object? v) => v is bool ? (v ? 'yes' : 'no') : '$v';

KdTone answerTone(Object? v)=>_answerTone(v);

KdTone _answerTone(Object? v) => v == 'yes' || v == true ? KdTone.ok : (v == 'partly' ? KdTone.warn : KdTone.plain);

/// One visible review: the answers, the comment, the facts of that job and the reply. A flag reports it when it breaks
/// the rules; disagreeing with it is what the reply is for.
class ReviewCard extends ConsumerWidget {
  final PublicReview review;
  final bool canReport;
  const ReviewCard({super.key, required this.review, this.canReport = true});

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final choice = await showReasonSheet(
      context,
      title: 'Report this review',
      lead: 'Reviews come down only for threats or abuse, personal information, not being about the work, or being used as leverage. If you simply disagree, reply to it instead.',
      codes: [for (final r in reviewReportReasons) ReasonCode(code: r.code, label: r.label, needsNote: true)],
      confirmLabel: 'Report',
    );
    if (choice == null || !context.mounted) return;
    try {
      await ref.read(reviewActionsProvider).report(review.id, reasonCode: choice.code, note: choice.note);
      if (context.mounted) KdToast.show(context, 'Reported. A person will look at it', kind: ToastKind.info);
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('${review.skillLabel} · ${formatAgo(review.at)}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (canReport)
              Pressable(
                onTap: () => _report(context, ref),
                semanticLabel: 'Report this review',
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.flag_outlined, size: 18, color: AppColors.text3)),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in review.answers.entries)
              if (_answerLabels.containsKey(e.key)) StatusPill('${_answerLabels[e.key]}: ${_answerText(e.value)}', tone: _answerTone(e.value)),
          ]),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('"${review.comment}"', style: AppTextStyles.bodyMedium.copyWith(height: 1.45)),
          ],
          if (review.facts != null) ...[
            const SizedBox(height: 10),
            Text(review.facts!.lines.join(' · '), style: AppTextStyles.hint),
          ],
          if (review.reply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
              child: Text('Their reply: ${review.reply}', style: AppTextStyles.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

/// A talent's track record: plain counts per skill, Proven levels, and the reviews, last 12 months first.
class TalentReputationSection extends StatefulWidget {
  final TalentReputation reputation;
  final bool canReport;
  const TalentReputationSection({super.key, required this.reputation, this.canReport = true});

  @override
  State<TalentReputationSection> createState() => _TalentReputationSectionState();
}

class _TalentReputationSectionState extends State<TalentReputationSection> {
  bool _older = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.reputation;
    if (r.isEmpty) {
      return KdCard(child: Text('No finished jobs on King Domain yet. Jobs, how they went and what clients said appear here.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)));
    }
    final recent = r.reviews.where((x) => !x.older).toList();
    final older = r.reviews.where((x) => x.older).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KdCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final s in r.skills) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s.line, style: AppTextStyles.bodyMedium)),
            if (r.proven.any((p) => p.proven)) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final p in r.proven.where((p) => p.proven)) StatusPill('Proven: ${p.skillLabel}', tone: KdTone.ok, icon: Icons.workspace_premium_outlined)]),
            ],
          ]),
        ),
        if (r.reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('What clients said', style: AppTextStyles.title),
          const SizedBox(height: 8),
          for (final x in recent) Padding(padding: const EdgeInsets.only(bottom: 8), child: ReviewCard(review: x, canReport: widget.canReport)),
          if (older.isNotEmpty && !_older)
            KdButton.secondary(label: 'Show older reviews (${older.length})', height: AppDimensions.buttonHeightSm, onPressed: () => setState(() => _older = true)),
          if (_older) for (final x in older) Padding(padding: const EdgeInsets.only(bottom: 8), child: ReviewCard(review: x, canReport: widget.canReport)),
        ],
      ],
    );
  }
}

/// What talents said about a client, as counts, and how they behave (D19). Nothing is shown until there is something to count.
class ClientReputationBlock extends StatelessWidget {
  final ClientReputation reputation;
  const ClientReputationBlock({super.key, required this.reputation});

  @override
  Widget build(BuildContext context) {
    final r = reputation;
    final t = r.tally;
    final lines = <String>[
      if (t.reviewed > 0) '${t.briefClear} of ${t.reviewed} talent${t.reviewed == 1 ? '' : 's'} said the brief was clear',
      if (t.reviewed > 0) '${t.paidFairly} of ${t.reviewed} said they paid and approved fairly',
      if (t.reviewed > 0) '${t.recommend} of ${t.reviewed} would recommend working with them',
      if (r.reviewHoursMedian != null) 'Reviews delivered work in about ${r.reviewHoursMedian! >= 48 ? '${(r.reviewHoursMedian! / 24).round()} days' : '${r.reviewHoursMedian} h'}',
      if (r.changeRoundsPerJob != null) '${r.changeRoundsPerJob} change round${r.changeRoundsPerJob == 1 ? '' : 's'} per job',
      if (r.jobsDone > 0) '${r.disputesLost} dispute${r.disputesLost == 1 ? '' : 's'} lost',
    ];
    if (lines.isEmpty) return Text('No finished jobs yet, so nothing from talents to show.', style: AppTextStyles.hint);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: AppTextStyles.bodySmall))]);
  }
}
