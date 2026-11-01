import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../../data/models/packages.dart';
import '../../providers/packages_provider.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/premium_sheet.dart';
import '../../widgets/kit/status_pill.dart';

/// Questions asked before applying (D28, D38). The client sees every question and answers it; the answer is then on the job
/// for every applicant, without the asker's name, so information is never paywalled. A talent can ask a question as a
/// premium feature; asking buys no better place.
class JobQuestionsSection extends ConsumerWidget {
  final Job job;
  final bool isClient;
  const JobQuestionsSection({super.key, required this.job, required this.isClient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(jobQuestionsProvider(job.id));
    final list = async.valueOrNull ?? const <JobQuestion>[];
    final canAsk = !isClient && job.awardedApplicationId == null && !job.closed && job.applicationStatus == JobApplicationStatus.notApplied;
    if (list.isEmpty && !canAsk) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: KdCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Questions about this job', style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text(isClient ? 'Answers are shown to everyone who applies, without names.' : 'Answers from the client, shown to everyone who applies.', style: AppTextStyles.hint),
          if (async.hasError) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Couldn\'t load the questions.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warn))),
          for (final q in list) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text(q.question, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
              if (q.mine) const StatusPill('You asked'),
            ]),
            const SizedBox(height: 2),
            if (q.answer != null)
              Text(q.answer!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2, height: 1.4))
            else if (q.canAnswer)
              Padding(padding: const EdgeInsets.only(top: 6), child: KdButton(label: 'Answer', variant: KdButtonVariant.soft, height: 40, onPressed: () => showKdSheet(context, builder: (_) => _AnswerSheet(job: job, question: q))))
            else
              Text('Waiting for the client to answer.', style: AppTextStyles.hint),
          ],
          if (canAsk) ...[
            const SizedBox(height: 12),
            KdButton.secondary(label: 'Ask a question before applying', icon: Icons.help_outline_rounded, height: 44, onPressed: () => _ask(context, ref)),
          ],
        ]),
      ),
    );
  }

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final status = await ref.read(premiumStatusProvider.future).catchError((_) => const PremiumStatus(enforced: false, billingConfigured: false, features: [], rule: ''));
    final f = status.of('pre_apply_question');
    if (!context.mounted) return;
    // With premium on and no purchase to spend, offer the purchase first; it unlocks exactly one question.
    if (status.enforced && (f?.credits ?? 0) == 0) {
      final bought = await offerPremium(context, feature: 'pre_apply_question', productId: f?.productId);
      if (!bought || !context.mounted) return;
    }
    await showKdSheet(context, builder: (_) => _AskSheet(job: job));
  }
}

class _AskSheet extends ConsumerStatefulWidget {
  final Job job;
  const _AskSheet({required this.job});

  @override
  ConsumerState<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends ConsumerState<_AskSheet> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    try {
      await ref.read(packageActionsProvider).ask(widget.job.id, _text.text.trim());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    KdToast.show(context, 'Sent. The answer will be on the job for everyone');
  }

  @override
  Widget build(BuildContext context) {
    final ok = _text.text.trim().length >= 10;
    return KdSheetBody(
      title: 'Ask the client',
      lead: 'Keep it about the job. No phone numbers, links or payment outside King Domain. The client\'s answer is shown to everyone who applies.',
      children: [
        const SizedBox(height: 12),
        TextField(controller: _text, maxLines: 3, maxLength: 300, autofocus: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'e.g. Is the logo for print as well as screen?')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))),
        const SizedBox(height: 12),
        KdButton(label: 'Send the question', busyLabel: 'Sending', onPressed: ok ? _send : null),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _AnswerSheet extends ConsumerStatefulWidget {
  final Job job;
  final JobQuestion question;
  const _AnswerSheet({required this.job, required this.question});

  @override
  ConsumerState<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends ConsumerState<_AnswerSheet> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    try {
      await ref.read(packageActionsProvider).answerQuestion(widget.job.id, widget.question.id, _text.text.trim());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    KdToast.show(context, 'Answered. Everyone who applies will see it');
  }

  @override
  Widget build(BuildContext context) {
    final ok = _text.text.trim().length >= 2;
    return KdSheetBody(
      title: widget.question.question,
      lead: 'Your answer is shown to everyone who applies, without the name of whoever asked. No contact details or payment outside King Domain.',
      children: [
        const SizedBox(height: 12),
        TextField(controller: _text, maxLines: 4, maxLength: 600, autofocus: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Your answer')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))),
        const SizedBox(height: 12),
        KdButton(label: 'Post the answer', busyLabel: 'Posting', onPressed: ok ? _send : null),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
