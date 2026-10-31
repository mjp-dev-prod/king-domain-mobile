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
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_stepper.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import 'skill_history.dart';
import 'submission_screen.dart';

void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

StatusPill _pill(SkillState s) => switch (s) {
  SkillState.verified => const StatusPill('Verified', tone: KdTone.ok, icon: Icons.check_rounded),
  SkillState.inReview => const StatusPill('In review', tone: KdTone.warn, pulse: true),
  SkillState.draft => const StatusPill('Draft', tone: KdTone.brand),
  SkillState.notYet => const StatusPill('Not yet', tone: KdTone.warn),
  SkillState.restricted => const StatusPill('Paused', tone: KdTone.bad),
  SkillState.notStarted => const StatusPill('To do', tone: KdTone.plain),
};

String _line(SkillHubEntry e) => switch (e.state) {
  SkillState.verified => 'You can apply for these jobs.',
  SkillState.inReview => 'Sent. We will tell you the moment there is a result.',
  SkillState.draft => 'You have a draft in progress.',
  SkillState.notYet => 'Read what fell short and send it again.',
  SkillState.restricted => e.restriction?.until == null ? "You can't submit in this skill." : 'You can submit again after ${formatDeadline(e.restriction!.until!).split(',').first}.',
  SkillState.notStarted => 'Prove it with two or three pieces of real work.',
};

/// Every skill and where the person stands in it. The way into proving one (PRD §3.1 step 3, §4.3).
class SkillsHubScreen extends ConsumerWidget {
  const SkillsHubScreen({super.key});

  void _go(BuildContext context, SkillHubEntry e) {
    final id = e.currentSubmissionId;
    final open = switch (e.state) {
      SkillState.draft || SkillState.inReview || SkillState.verified || SkillState.notYet => id != null,
      _ => false,
    };
    _open(context, open ? SubmissionScreen(submissionId: id!) : SkillIntroScreen(entry: e));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(skillHubProvider);
    return Scaffold(
      body: hub.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), Skeleton(height: 26, width: 180, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load your skills. Check your connection and try again.", onRetry: () async => ref.invalidate(skillHubProvider))),
        data: (h) {
          final verified = h.skills.where((s) => s.state == SkillState.verified).length;
          return ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
            children: [
              ContractHeader(
                title: 'Your skills',
                sub: 'Get verified in a skill to apply for its jobs. Real work, checked by people.',
                pill: StatusPill(verified == 0 ? 'None yet' : '$verified verified', tone: verified == 0 ? KdTone.brand : KdTone.ok),
              ),
              const SizedBox(height: 16),
              if (!h.uploadsAvailable) ...[
                const NoticeCard(tone: KdTone.warn, icon: Icons.cloud_off_outlined, title: 'Uploads are paused', body: "You can read about each skill, but adding files isn't possible right now. Try again later."),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < h.skills.length; i++) ...[
                RiseIn(delay: Duration(milliseconds: 40 * i), child: _SkillCard(entry: h.skills[i], onTap: () => _go(context, h.skills[i]))),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              Text('Each skill is reviewed by two people who work in it. You can prove more than one.', textAlign: TextAlign.center, style: AppTextStyles.hint),
            ],
          );
        },
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final SkillHubEntry entry;
  final VoidCallback onTap;
  const _SkillCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = switch (entry.state) {
      SkillState.verified => KdTone.ok,
      SkillState.restricted => KdTone.bad,
      _ => KdTone.plain,
    };
    return Pressable(
      onTap: onTap,
      semanticLabel: '${entry.label}, ${_line(entry)}',
      child: KdCard(
        tone: tone,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(entry.label, style: AppTextStyles.title)),
                _pill(entry.state),
              ]),
              const SizedBox(height: 4),
              Text(_line(entry), style: AppTextStyles.hint),
            ]),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
        ]),
      ),
    );
  }
}

/// Before the first attempt (or while paused): what the process is, how long it takes, and the rules.
class SkillIntroScreen extends ConsumerWidget {
  final SkillHubEntry entry;
  const SkillIntroScreen({super.key, required this.entry});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    try {
      final s = await ref.read(submissionActionsProvider).startOrContinue(entry.skillKey);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SubmissionScreen(submissionId: s.id)));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      KdToast.show(context, e.message, kind: ToastKind.error);
      // Something moved while this screen was open (a result, a pause): refresh so the hub tells the truth.
      ref.invalidate(skillHubProvider);
      throw const ShownError();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = entry.restriction;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
        children: [
          ContractHeader(title: entry.label, sub: 'Prove it once, and clients see you are verified.', pill: _pill(entry.state)),
          const SizedBox(height: 16),
          if (r != null)
            RiseIn(
              child: NoticeCard(
                tone: KdTone.bad,
                icon: Icons.pause_circle_outline_rounded,
                title: r.permanent ? "You can't submit in ${entry.label}" : 'Paused until ${formatDeadline(r.until!).split(',').first}',
                body: r.permanent ? 'This follows work that was not yours.' : 'This follows sending work again that had already been turned down, unchanged.',
                quote: r.reason.isEmpty ? null : r.reason,
                footnote: 'You can still prove your other skills. If you think this is wrong, contact support from your profile.',
              ),
            )
          else ...[
            RiseIn(
              child: KdCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('How it works', style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  const KdStepper(
                    steps: [
                      KdStep(label: 'Send 2 or 3 pieces of real work', subtitle: 'With working files, drafts and a short walkthrough video', state: KdStepState.current),
                      KdStep(label: 'A person checks it is yours', state: KdStepState.later),
                      KdStep(label: 'Two reviewers score it', subtitle: 'Without knowing who you are', state: KdStepState.later),
                      KdStep(label: 'You get the result, with reasons', state: KdStepState.later),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const NoticeCard(
              tone: KdTone.plain,
              icon: Icons.schedule_rounded,
              title: 'We aim to reply within $replyDays days',
              body: 'From the moment you send it. If it takes longer we will tell you why.',
            ),
            const SizedBox(height: 12),
            const NoticeCard(
              tone: KdTone.warn,
              icon: Icons.gavel_rounded,
              title: 'Send only your own work',
              body: 'If it is not yours you are banned from this skill. If you are told Not yet, fix it before sending again: sending the same files unchanged means 2 months out of this skill, then 3.',
            ),
            const SizedBox(height: 16),
            KdButton(label: entry.state == SkillState.notYet ? 'Fix it and send again' : 'Start', busyLabel: 'Opening', onPressed: () => _start(context, ref)),
          ],
          const SizedBox(height: 24),
          SkillHistory(skillKey: entry.skillKey),
        ],
      ),
    );
  }
}
