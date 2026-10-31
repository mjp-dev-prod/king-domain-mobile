import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../../data/models/skill_submission.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import '../skills/skills_hub_screen.dart';

/// One piece of verified work the talent may show, from a verified submission or an older proof item.
class _Choice {
  final String type; // 'piece' | 'proof'
  final String id;
  final String title;
  final String detail;
  const _Choice(this.type, this.id, this.title, this.detail);
  String get key => '$type:$id';
}

/// Apply to a structured job (PRD §3.1 step 8): an answer to the brief, 1 to 3 pieces of VERIFIED work, and the
/// client's screening questions. Price is the client's; there is nothing to bid (D22).
class ApplyScreen extends ConsumerStatefulWidget {
  final Job job;
  const ApplyScreen({super.key, required this.job});

  @override
  ConsumerState<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends ConsumerState<ApplyScreen> {
  final _answer = TextEditingController();
  late final List<TextEditingController> _screening = [for (final _ in widget.job.screeningQuestions) TextEditingController()];
  final Set<String> _picked = {};
  String? _answerError;
  String? _piecesError;
  String? _screeningError;
  String? _formError;

  @override
  void dispose() {
    _answer.dispose();
    for (final c in _screening) {
      c.dispose();
    }
    super.dispose();
  }

  List<_Choice> _choices() {
    final job = widget.job;
    final out = <_Choice>[];
    final hub = ref.watch(skillHubProvider).valueOrNull;
    final entry = hub?.skills.where((s) => s.skillKey == job.skillKey && s.state == SkillState.verified).firstOrNull;
    final subId = entry?.currentSubmissionId;
    if (subId != null) {
      final sub = ref.watch(submissionProvider(subId)).valueOrNull;
      for (final p in sub?.pieces ?? const <SubmissionPiece>[]) {
        out.add(_Choice('piece', p.id, p.displayTitle, [p.role, p.madeOn].where((x) => x.isNotEmpty).join(' · ')));
      }
    }
    final profile = ref.watch(talentProfileProvider).valueOrNull;
    for (final p in profile?.proofItems ?? const <ProofItem>[]) {
      if (p.category == job.category && p.status == ProofReviewStatus.verified && !p.title.endsWith('(verified)')) {
        out.add(_Choice('proof', p.id, p.title, 'Earlier proof'));
      }
    }
    return out;
  }

  bool _check() {
    final answer = _answer.text.trim();
    setState(() {
      _answerError = answer.length < 20 ? 'Say in at least 20 characters why you are right for this.' : answer.length > 1500 ? 'Keep it under 1500 characters.' : null;
      _piecesError = _picked.isEmpty ? 'Choose 1 to 3 pieces of your verified work to show.' : null;
      _screeningError = _screening.any((c) => c.text.trim().isEmpty) ? 'Answer every question the client asked.' : null;
    });
    return _answerError == null && _piecesError == null && _screeningError == null;
  }

  Future<void> _send() async {
    if (!_check()) throw const ShownError();
    setState(() => _formError = null);
    final job = widget.job;
    try {
      await ref.read(discoveryActionsProvider).apply(
        job.id,
        revision: job.revision,
        answer: _answer.text.trim(),
        pieces: [for (final k in _picked) {'type': k.split(':').first, 'id': k.split(':').last}],
        screeningAnswers: [for (final c in _screening) c.text.trim()],
      );
    } on ApiException catch (e) {
      if (e.code == 'terms_changed') {
        ref.invalidate(jobDetailProvider(job.id));
        if (!mounted) return;
        Navigator.of(context).pop();
        KdToast.show(context, 'This job was just edited. Read the new details, then apply again.');
        throw const ShownError();
      }
      setState(() => _formError = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    KdToast.show(context, 'Application sent to ${job.clientName}');
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final choices = _choices();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
        children: [
          ContractHeader(title: 'Apply', sub: job.title, pill: StatusPill(formatMoney(job.budget, job.currency), tone: KdTone.plain)),
          const SizedBox(height: 16),
          RiseIn(
            child: NoticeCard(
              tone: KdTone.plain,
              icon: Icons.payments_outlined,
              title: 'The price is ${formatMoney(job.budget, job.currency)}${job.jobType.priceNote}',
              body: '${job.clientName} set it, so there is nothing to bid. If they pick you, they pay it plus ${AppBrand.name}\'s 10% before you start, and you receive the full price.',
            ),
          ),
          const SizedBox(height: 16),
          KdTextField(controller: _answer, label: 'Why you, for this brief', hintText: 'What you would do and why it fits your work', maxLines: 6),
          if (_answerError != null) _Error(_answerError!),
          const SizedBox(height: 20),
          Text('Show your best work for this job', style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text('Pick 1 to 3. Only verified work can be shown, and the client sees it with your application.', style: AppTextStyles.hint),
          const SizedBox(height: 10),
          if (choices.isEmpty)
            NoticeCard(
              tone: KdTone.warn,
              icon: Icons.inventory_2_outlined,
              title: 'No verified pieces to show',
              body: 'Your verified work for ${job.skillOrCategory} appears here once it is verified.',
              actions: [KdButton(label: 'Your skills', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkillsHubScreen())))],
            ),
          for (final c in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                onTap: () => setState(() {
                  if (_picked.contains(c.key)) {
                    _picked.remove(c.key);
                  } else if (_picked.length < 3) {
                    _picked.add(c.key);
                  } else {
                    KdToast.show(context, 'You can show up to 3 pieces.');
                  }
                }),
                semanticLabel: '${c.title}, ${_picked.contains(c.key) ? 'chosen' : 'not chosen'}',
                child: KdCard(
                  tone: _picked.contains(c.key) ? KdTone.brand : KdTone.plain,
                  child: Row(children: [
                    Icon(_picked.contains(c.key) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: _picked.contains(c.key) ? AppColors.primaryText : AppColors.text3),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.title, style: AppTextStyles.title), if (c.detail.isNotEmpty) Text(c.detail, style: AppTextStyles.hint)])),
                    const Icon(Icons.verified_outlined, size: 18, color: AppColors.ok),
                  ]),
                ),
              ),
            ),
          if (_piecesError != null) _Error(_piecesError!),
          if (job.screeningQuestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text("The client's questions", style: AppTextStyles.title),
            const SizedBox(height: 10),
            for (var i = 0; i < job.screeningQuestions.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: KdTextField(controller: _screening[i], label: job.screeningQuestions[i], maxLines: 3)),
            if (_screeningError != null) _Error(_screeningError!),
          ],
          const SizedBox(height: 20),
          Text('${job.clientName} will see your name, your verified skills and facts, the pieces you chose and your answers. They never see your contact details.', style: AppTextStyles.hint),
          if (_formError != null) ...[const SizedBox(height: 10), Text(_formError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))],
          const SizedBox(height: 14),
          KdButton(label: 'Send application', busyLabel: 'Sending', onPressed: _send),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String text;
  const _Error(this.text);

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)));
}
