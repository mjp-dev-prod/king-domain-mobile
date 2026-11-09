import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/skill_submission.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart' show SkeletonCard;
import 'submission_screen.dart';

/// Earlier attempts in one skill, newest first. Nothing is ever deleted, so the person can always see what
/// they sent and what they were told (PRD §4.3).
class SkillHistory extends ConsumerWidget {
  final String skillKey;

  /// The attempt on screen already, so it isn't listed again as "earlier".
  final String? exceptId;
  const SkillHistory({super.key, required this.skillKey, this.exceptId});

  static String statusText(HistoryEntry e) => switch (e.status) {
    SubmissionStatus.verified => 'Verified',
    SubmissionStatus.notYet => e.result?.kind == 'authenticity' ? 'Stopped at the first check' : 'Not yet',
    SubmissionStatus.removed => 'Removed',
    SubmissionStatus.authenticity => 'Being checked',
    SubmissionStatus.review => 'With reviewers',
    SubmissionStatus.draft => 'Draft',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(skillHistoryProvider(skillKey));
    return history.when(
      loading: () => const SkeletonCard(),
      // History is a nice-to-have on these screens: if it fails the rest still works, so say so quietly.
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text("Couldn't load your earlier attempts.", style: AppTextStyles.hint),
      ),
      data: (all) {
        final entries = [for (final e in all) if (e.id != exceptId) e];
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Earlier attempts', style: AppTextStyles.title),
            const SizedBox(height: 8),
            ListGroup(
              rows: [
                for (final e in entries)
                  ListRow(
                    icon: e.status == SubmissionStatus.verified ? Icons.verified_outlined : Icons.history_rounded,
                    title: statusText(e),
                    sub: e.submittedAt == null ? null : 'Sent ${formatDeadline(e.submittedAt!)}',
                    subTone: e.status == SubmissionStatus.verified ? KdTone.ok : KdTone.plain,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubmissionScreen(submissionId: e.id))),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Tap one to see what you sent and what you were told.', style: AppTextStyles.hint.copyWith(color: AppColors.text3)),
          ],
        );
      },
    );
  }
}
