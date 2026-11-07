import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../../data/models/job.dart';
import '../../../data/models/skill.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/skills_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/brief/brief_form.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import 'browse_talents_screen.dart';
import 'talent_profile_screen.dart';

String _promiseText(ShortlistPromise p) => p.hours == null
    ? 'We will tell you how long this usually takes once we have sent a few.'
    : 'Usually within ${p.hours} hour${p.hours == 1 ? '' : 's'}, a promise we keep 9 times in 10.';

/// "Find someone for me" (PRD §3.2 step 3; D24): describe the job once, and someone on the King Domain team picks 3 to 5
/// verified talents, asks each one first, and sends only those who say yes, with a line on why each fits. People pick,
/// not an algorithm, and nothing ranks talents (D23). "Shortlist" is kept for a client's own applicants, so it isn't
/// used for this service on screen (Victor, 2026-11-07: the word read as automatic suggestions).
class FindSomeoneScreen extends ConsumerWidget {
  const FindSomeoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shortlistsProvider);
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load this. Check your connection and try again.", onRetry: () async => ref.invalidate(shortlistsProvider))),
        data: (d) {
          final waiting = d.requests.where((r) => r.waiting).length;
          return ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
            children: [
              ContractHeader(title: 'Find someone for me', sub: 'Tell us what you need. Someone on our team picks the people, not an algorithm.', pill: StatusPill(waiting == 0 ? 'No requests waiting' : '$waiting waiting', tone: waiting == 0 ? KdTone.plain : KdTone.warn)),
              const SizedBox(height: 16),
              const RiseIn(child: _HowItWorks()),
              const SizedBox(height: 12),
              RiseIn(child: NoticeCard(tone: KdTone.plain, icon: Icons.schedule_rounded, title: 'How long it takes', body: _promiseText(d.promise))),
              const SizedBox(height: 12),
              KdButton(label: 'Ask us to find someone', icon: Icons.person_search_outlined, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewShortlistScreen()))),
              const SizedBox(height: 20),
              if (d.requests.isEmpty)
                const EmptyState(icon: Icons.person_search_outlined, title: 'No requests yet', body: 'Ask us to find someone and your request appears here, then the people who said yes.'),
              for (final r in d.requests) Padding(padding: const EdgeInsets.only(bottom: 14), child: _RequestCard(request: r, promise: d.promise)),
            ],
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ShortlistRequestView request;
  final ShortlistPromise promise;
  const _RequestCard({required this.request, required this.promise});

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KdCard(
          tone: r.waiting ? KdTone.warn : KdTone.ok,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.skillLabel}: people for you', style: AppTextStyles.title),
                Text(r.waiting ? 'Asked ${formatAgo(r.requestedAt)}. ${_promiseText(promise)}' : 'Sent ${r.sentAt == null ? '' : formatAgo(r.sentAt!)}', style: AppTextStyles.bodySmall),
              ]),
            ),
            r.waiting ? const StatusPill('Working on it', tone: KdTone.warn, pulse: true) : StatusPill('${r.picks.length} found', tone: KdTone.ok, icon: Icons.check_rounded),
          ]),
        ),
        for (final p in r.picks)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text('Why: ${p.reason}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2))),
              TalentCardView(talent: p.talent, onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TalentProfileScreen(talentId: p.talent.id)))),
            ]),
          ),
      ],
    );
  }
}

/// The request form: the skill, the shape of the job, the same structured brief a job post asks for, a budget.
class NewShortlistScreen extends ConsumerStatefulWidget {
  const NewShortlistScreen({super.key});

  @override
  ConsumerState<NewShortlistScreen> createState() => _NewShortlistScreenState();
}

class _NewShortlistScreenState extends ConsumerState<NewShortlistScreen> {
  String? _skill;
  JobType _type = JobType.oneDelivery;
  String _currency = 'NGN';
  final _price = TextEditingController();
  final _note = TextEditingController();
  final _answers = BriefAnswers();
  String? _error;

  // Milestones need their own editor, which belongs to posting a job: a shortlist asks for the other three shapes.
  static const _types = [JobType.oneDelivery, JobType.monthly, JobType.hourly];

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    _answers.dispose();
    super.dispose();
  }

  String? _validate(BriefSpec spec) {
    if (_skill == null) return 'Choose the skill you need.';
    final problem = _answers.validate(spec.fields);
    if (problem != null) return problem;
    if (_type != JobType.hourly && (double.tryParse(_price.text.trim()) ?? 0) <= 0) return 'Say what you can pay.';
    return null;
  }

  Future<void> _send(BriefSpec spec) async {
    final problem = _validate(spec);
    if (problem != null) {
      setState(() => _error = problem);
      throw const ShownError();
    }
    setState(() => _error = null);
    final brief = _answers.toJson(spec.fields);
    try {
      await ref.read(discoveryActionsProvider).requestShortlist({
        'skillKey': _skill,
        'jobType': _type.name,
        'currency': _currency,
        if (_type != JobType.hourly) 'price': double.parse(_price.text.trim()),
        'brief': brief,
        'note': _note.text.trim(),
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    KdToast.show(context, 'Sent. We will ask people first, then send you those who are free.');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(skillCatalogProvider).valueOrNull;
    final specAsync = _skill == null ? null : ref.watch(briefSpecProvider('$_skill|${_type.name}'));
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
        children: [
          // No price is shown: the service will be paid (Victor, 2026-11-07), and how much is an open money decision.
          const ContractHeader(title: 'Ask us to find someone', sub: 'The same brief a job asks for, so the people we pick are the right ones.', pill: StatusPill('Picked by our team')),
          const SizedBox(height: 16),
          Text('Skill', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in (catalog?.skills ?? const <Skill>[]).where((s) => s.open)) KdChoiceChip(label: s.label, selected: _skill == s.key, onTap: () => setState(() => _skill = s.key)),
          ]),
          const SizedBox(height: 16),
          Text('Kind of job', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final t in _types) KdChoiceChip(label: t.label, selected: _type == t, onTap: () => setState(() => _type = t))]),
          const SizedBox(height: 16),
          if (specAsync != null)
            specAsync.when(
              loading: () => const SkeletonCard(),
              error: (_, _) => ErrorState(message: "Couldn't load the form. Check your connection and try again.", onRetry: () async => ref.invalidate(briefSpecProvider('$_skill|${_type.name}'))),
              data: (spec) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final f in spec.fields.where((f) => f.kind != BriefKind.milestones)) Padding(padding: const EdgeInsets.only(bottom: 12), child: BriefFieldInput(field: f, answers: _answers, onChanged: () => setState(() {}))),
                Text('Paid in', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [KdChoiceChip(label: 'Naira', selected: _currency == 'NGN', onTap: () => setState(() => _currency = 'NGN')), KdChoiceChip(label: 'Dollars', selected: _currency == 'USD', onTap: () => setState(() => _currency = 'USD'))]),
                const SizedBox(height: 12),
                if (_type != JobType.hourly) KdTextField(controller: _price, label: _type == JobType.monthly ? 'Budget for one month' : 'Budget', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                KdTextField(controller: _note, label: 'Anything else we should know (optional)', maxLines: 3),
                if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))],
                const SizedBox(height: 14),
                KdButton(label: 'Send request', busyLabel: 'Sending', onPressed: () => _send(spec)),
              ]),
            ),
        ],
      ),
    );
  }

}

/// Says plainly what happens, so it isn't read as automatic suggestions.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'You describe the job, the same way you would post one.',
      'Someone on our team picks 3 to 5 verified people whose work fits.',
      'We ask each of them first. Nobody is shown to you unless they say they are free.',
      'You get those who said yes, with a line on why each one fits. Open each to see their work and message them.',
    ];
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How it works', style: AppTextStyles.title),
        const SizedBox(height: 10),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 22, child: Text('${i + 1}', style: AppTextStyles.label.copyWith(color: AppColors.primaryText))),
              Expanded(child: Text(steps[i], style: AppTextStyles.bodySmall)),
            ]),
          ),
      ]),
    );
  }
}
