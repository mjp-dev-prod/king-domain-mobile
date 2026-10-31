import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../../data/models/job.dart';
import '../../../data/models/skill.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/skills_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';

enum _Step { type, skill, brief, price, ask, review }

class _MilestoneRow {
  final title = TextEditingController();
  final amount = TextEditingController();
  final days = TextEditingController(text: '7');
  void dispose() {
    title.dispose();
    amount.dispose();
    days.dispose();
  }
}

/// Post a job (PRD §3.2 step 4): type, skill, the skill's structured brief, price and currency, screening
/// questions, who may see it, then a review that states every money rule before the client commits. A new
/// client's first post is read by a person before it goes live (D17), and the end of the flow says so plainly.
class PostJobFlow extends ConsumerStatefulWidget {
  final VoidCallback? onPosted;

  /// A post the team sent back, to change and send again.
  final Job? editing;
  const PostJobFlow({super.key, this.onPosted, this.editing});

  @override
  ConsumerState<PostJobFlow> createState() => _PostJobFlowState();
}

class _PostJobFlowState extends ConsumerState<PostJobFlow> {
  _Step _step = _Step.type;
  JobType? _type;
  String? _skillKey;
  String _currency = 'NGN';
  bool _inviteOnly = false;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _days = TextEditingController(text: '7');
  final Map<String, TextEditingController> _fields = {};
  final Map<String, String> _chosen = {};
  final List<_MilestoneRow> _milestones = [_MilestoneRow(), _MilestoneRow()];
  final List<TextEditingController> _questions = [];
  String? _error;
  final _scroll = ScrollController();
  String? _doneNote;
  bool _done = false;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type = e.jobType;
      _skillKey = e.skillKey;
      _currency = e.currency;
      _inviteOnly = e.inviteOnly;
      _title.text = e.title;
      _description.text = e.description;
      _price.text = e.budget.round().toString();
      _days.text = '${e.deliveryDays ?? 7}';
      for (final q in e.screeningQuestions) {
        _questions.add(TextEditingController(text: q));
      }
      for (final entry in e.brief.entries) {
        if (entry.key == 'milestones') {
          _milestones.clear();
          for (final m in (entry.value as List).cast<Map<String, dynamic>>()) {
            _milestones.add(_MilestoneRow()
              ..title.text = '${m['title']}'
              ..amount.text = '${m['amount']}'
              ..days.text = '${m['days']}');
          }
        } else if (entry.value is String && _isChoiceKey(entry.key)) {
          _chosen[entry.key] = entry.value as String;
        } else {
          _fields[entry.key] = TextEditingController(text: '${entry.value}');
        }
      }
      _step = _Step.brief;
    }
  }

  static bool _isChoiceKey(String k) => k == 'usageRights' || k == 'aspectRatio';

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_title, _description, _price, _days, ..._fields.values, ..._questions]) {
      c.dispose();
    }
    for (final m in _milestones) {
      m.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String key) => _fields.putIfAbsent(key, TextEditingController.new);

  /// Shows a problem at the top, under the step's heading, and scrolls there: the button that raised it is often
  /// at the bottom of the screen, and a message down there would be missed.
  void _fail(String message) {
    setState(() => _error = message);
    if (_scroll.hasClients) unawaited(_scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic));
  }

  void _go(_Step s) => setState(() {
    _step = s;
    _error = null;
  });

  void _back() {
    if (_step == _Step.type || (widget.editing != null && _step == _Step.brief)) {
      Navigator.of(context).maybePop();
    } else {
      _go(_Step.values[_step.index - 1]);
    }
  }

  // ── Validation per step: inline, and nothing is lost going back ──

  String? _validBrief(BriefSpec spec) {
    if (_title.text.trim().length < 5) return 'Give the job a title of at least 5 characters.';
    if (_description.text.trim().length < 20) return 'Describe the job in at least 20 characters.';
    for (final f in spec.fields) {
      switch (f.kind) {
        case BriefKind.text:
          if (f.required && _field(f.key).text.trim().isEmpty) return '${f.label}: fill this in.';
        case BriefKind.int:
          final raw = _field(f.key).text.trim();
          if (raw.isEmpty && !f.required) break;
          final n = int.tryParse(raw);
          if (n == null || n < (f.min ?? 0) || n > (f.max ?? 1 << 30)) return '${f.label}: a whole number from ${f.min ?? 0} to ${f.max}.';
        case BriefKind.choice:
          if (f.required && !_chosen.containsKey(f.key)) return '${f.label}: choose one.';
        case BriefKind.milestones:
          if (_milestones.length < 2) return 'Add at least 2 milestones.';
          for (final m in _milestones) {
            if (m.title.text.trim().isEmpty) return 'Each milestone needs a title.';
            if ((double.tryParse(m.amount.text.trim()) ?? 0) <= 0) return 'Each milestone needs an amount.';
            final d = int.tryParse(m.days.text.trim());
            if (d == null || d < 1 || d > 60) return 'Each milestone takes 1 to 60 days.';
          }
      }
    }
    return null;
  }

  double? get _priceValue {
    switch (_type) {
      case JobType.milestones:
        return _milestones.fold<double>(0, (sum, m) => sum + (double.tryParse(m.amount.text.trim()) ?? 0));
      case JobType.hourly:
        final rate = double.tryParse(_field('hourlyRate').text.trim());
        final hours = double.tryParse(_field('weeklyCapHours').text.trim());
        return rate == null || hours == null ? null : rate * hours;
      default:
        return double.tryParse(_price.text.trim());
    }
  }

  String? _validPrice() {
    if ((_priceValue ?? 0) <= 0) return 'The price must be more than zero.';
    if (_type == JobType.oneDelivery) {
      final d = int.tryParse(_days.text.trim());
      if (d == null || d < 1 || d > 60) return 'Delivery is 1 to 60 days.';
    }
    return null;
  }

  String? _validAsk() {
    for (final q in _questions) {
      if (q.text.trim().length < 5) return 'Each question needs at least 5 characters. Remove the ones you do not need.';
    }
    return null;
  }

  Map<String, dynamic> _body(BriefSpec spec) {
    final brief = <String, dynamic>{};
    for (final f in spec.fields) {
      switch (f.kind) {
        case BriefKind.text:
          final v = _field(f.key).text.trim();
          if (v.isNotEmpty) brief[f.key] = v;
        case BriefKind.int:
          final n = int.tryParse(_field(f.key).text.trim());
          if (n != null) brief[f.key] = n;
        case BriefKind.choice:
          if (_chosen[f.key] != null) brief[f.key] = _chosen[f.key];
        case BriefKind.milestones:
          brief['milestones'] = [for (final m in _milestones) {'title': m.title.text.trim(), 'amount': double.parse(m.amount.text.trim()), 'days': int.parse(m.days.text.trim())}];
      }
    }
    return {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'skillKey': _skillKey,
      'jobType': _type!.name,
      'brief': brief,
      if (_type == JobType.oneDelivery || _type == JobType.monthly) 'price': _priceValue,
      'currency': _currency,
      if (_type == JobType.oneDelivery) 'deliveryDays': int.parse(_days.text.trim()),
      'screeningQuestions': [for (final q in _questions) q.text.trim()],
      'visibility': _inviteOnly ? 'invite' : 'public',
    };
  }

  Future<void> _submit(BriefSpec spec) async {
    final actions = ref.read(discoveryActionsProvider);
    try {
      final body = _body(spec);
      if (widget.editing != null) {
        final r = await actions.editJob(widget.editing!.id, body);
        setState(() {
          _done = true;
          _held = r.job.heldForScreening;
          _doneNote = r.resubmitted ? 'We sent it back for another look.' : null;
        });
      } else {
        final r = await actions.postJob(body);
        setState(() {
          _done = true;
          _held = r.held;
          _doneNote = r.reason == 'flagged' ? 'It was held because it mentions payment or a program outside King Domain.' : null;
        });
      }
    } on ApiException catch (e) {
      _fail(e.message);
      // The server says which field was wrong: take the client back to the step that has it.
      final field = e.data?['field'] as String?;
      if (field != null) {
        _go(field == 'price' ? _Step.price : _Step.brief);
        _fail(e.message);
      }
      throw const ShownError();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _Done(held: _held, note: _doneNote, editing: widget.editing != null, onDone: widget.onPosted ?? () => Navigator.of(context).maybePop());
    final catalog = ref.watch(skillCatalogProvider);
    final specAsync = (_type != null && _skillKey != null) ? ref.watch(briefSpecProvider('$_skillKey|${_type!.name}')) : null;

    final headline = switch (_step) {
      _Step.type => 'What kind of job is it?',
      _Step.skill => 'Which skill do you need?',
      _Step.brief => 'The brief',
      _Step.price => 'Price and delivery',
      _Step.ask => 'Who can see it, and what to ask',
      _Step.review => 'Check it, then post',
    };

    return Scaffold(
      body: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 120),
        children: [
          ContractHeader(
            title: widget.editing != null ? 'Change your job' : 'Post a job',
            sub: headline,
            pill: StatusPill('Step ${_step.index + 1} of ${_Step.values.length}', tone: KdTone.brand),
            action: _step == _Step.type && widget.editing == null ? null : IconButton(tooltip: 'Back one step', icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
          ),
          const SizedBox(height: 16),
          if (widget.editing?.rejection != null) ...[
            NoticeCard(tone: KdTone.warn, icon: Icons.edit_note_rounded, title: 'It needs a change before it goes live', body: _rejectionText(widget.editing!.rejection!), quote: widget.editing!.rejection!.note),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)), const SizedBox(height: 12)],
          RiseIn(key: ValueKey(_step), child: _body0(catalog, specAsync)),
        ],
      ),
    );
  }

  String _rejectionText(PostRejection r) => switch (r.reasonCode) {
    'contact_details' => 'It asks talents to contact you outside King Domain.',
    'outside_payment' => 'It asks for payment, or offers it, outside King Domain.',
    'pay_to_apply' => 'It asks talents to pay before work.',
    'vague' => 'The brief is too vague to judge the work against.',
    'not_a_job' => 'It is not a job a talent can do remotely.',
    'unsafe' => 'It could put a talent at risk.',
    _ => 'A person read it and asked for a change.',
  };

  Widget _body0(AsyncValue<SkillCatalog> catalog, AsyncValue<BriefSpec>? spec) {
    switch (_step) {
      case _Step.type:
        return Column(children: [
          for (final t in JobType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () {
                  setState(() => _type = t);
                  _go(_Step.skill);
                },
                semanticLabel: '${t.label}. ${t.hint}',
                child: KdCard(
                  tone: _type == t ? KdTone.brand : KdTone.plain,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.label, style: AppTextStyles.title), const SizedBox(height: 4), Text(t.hint, style: AppTextStyles.bodySmall)]),
                ),
              ),
            ),
          Text('There are no contests: nobody works for free hoping to be picked.', style: AppTextStyles.hint),
        ]);
      case _Step.skill:
        return catalog.when(
          loading: () => const Column(children: [SkeletonCard(), SizedBox(height: 10), SkeletonCard()]),
          error: (_, _) => ErrorState(message: "Couldn't load the skills. Check your connection and try again.", onRetry: () async => ref.invalidate(skillCatalogProvider)),
          data: (c) => Column(children: [
            for (final s in c.skills.where((s) => s.open))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Pressable(
                  onTap: () {
                    setState(() => _skillKey = s.key);
                    _go(_Step.brief);
                  },
                  semanticLabel: s.label,
                  child: KdCard(tone: _skillKey == s.key ? KdTone.brand : KdTone.plain, child: Row(children: [Expanded(child: Text(s.label, style: AppTextStyles.title)), const Icon(Icons.chevron_right_rounded, color: AppColors.text3)])),
                ),
              ),
            Text('Only people verified in this skill can apply.', style: AppTextStyles.hint),
          ]),
        );
      case _Step.brief:
        if (spec == null) return const SizedBox.shrink();
        return spec.when(
          loading: () => const Column(children: [SkeletonCard(), SizedBox(height: 10), SkeletonCard()]),
          error: (_, _) => ErrorState(message: "Couldn't load the brief form. Check your connection and try again.", onRetry: () async => ref.invalidate(briefSpecProvider('$_skillKey|${_type!.name}'))),
          data: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KdTextField(controller: _title, label: 'Job title', textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            KdTextField(controller: _description, label: 'What the job is, in your words', maxLines: 5),
            const SizedBox(height: 18),
            Text('The brief the work is judged against', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text('Clear is kind: it is what a review or a dispute is judged against later.', style: AppTextStyles.hint),
            const SizedBox(height: 12),
            for (final f in s.fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: _fieldWidget(f)),
            const SizedBox(height: 6),
            KdButton(
              label: 'Continue',
              onPressed: () {
                final problem = _validBrief(s);
                if (problem != null) {
                  _fail(problem);
                  throw const ShownError();
                }
                _go(_Step.price);
              },
            ),
          ]),
        );
      case _Step.price:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Paid in', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            KdChoiceChip(label: 'Naira', selected: _currency == 'NGN', onTap: () => setState(() => _currency = 'NGN')),
            KdChoiceChip(label: 'Dollars', selected: _currency == 'USD', onTap: () => setState(() => _currency = 'USD')),
          ]),
          if (_currency == 'USD') ...[
            const SizedBox(height: 8),
            Text('Dollar jobs are paid by card. Talents are paid in naira at the day\'s rate, which they see before they apply.', style: AppTextStyles.hint),
          ],
          const SizedBox(height: 16),
          if (_type == JobType.oneDelivery || _type == JobType.monthly)
            KdTextField(controller: _price, label: _type == JobType.monthly ? 'Price for one month' : 'Price', keyboardType: TextInputType.number)
          else
            NoticeCard(
              tone: KdTone.plain,
              icon: Icons.calculate_outlined,
              title: _type == JobType.milestones ? 'The price is the milestones added up' : 'The price is rate times hours',
              body: _priceValue == null || _priceValue == 0 ? 'Fill in the brief first.' : '${formatMoney(_priceValue!, _currency)}${_type!.priceNote}',
            ),
          if (_type == JobType.oneDelivery) ...[
            const SizedBox(height: 12),
            KdTextField(controller: _days, label: 'Days to deliver, from when you pay (1 to 60)', keyboardType: TextInputType.number),
          ],
          const SizedBox(height: 16),
          KdButton(
            label: 'Continue',
            onPressed: () {
              final problem = _validPrice();
              if (problem != null) {
                _fail(problem);
                throw const ShownError();
              }
              _go(_Step.ask);
            },
          ),
        ]);
      case _Step.ask:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Who can see this job', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            KdChoiceChip(label: 'Everyone verified', selected: !_inviteOnly, onTap: () => setState(() => _inviteOnly = false)),
            KdChoiceChip(label: 'Only people I invite', selected: _inviteOnly, onTap: () => setState(() => _inviteOnly = true)),
          ]),
          const SizedBox(height: 6),
          Text(_inviteOnly ? 'Nobody sees it until you invite them (up to 20, each for 72 hours).' : 'Applications stop at 50 applicants or after 5 days. You can reopen it later.', style: AppTextStyles.hint),
          const SizedBox(height: 18),
          Text('Questions for applicants (optional, up to 3)', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < _questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: KdTextField(controller: _questions[i], label: 'Question ${i + 1}')),
                IconButton(tooltip: 'Remove question ${i + 1}', icon: const Icon(Icons.close_rounded, color: AppColors.text3), onPressed: () => setState(() => _questions.removeAt(i).dispose())),
              ]),
            ),
          if (_questions.length < 3) KdButton.secondary(label: 'Add a question', icon: Icons.add_rounded, height: AppDimensions.buttonHeightSm, onPressed: () => setState(() => _questions.add(TextEditingController()))),
          const SizedBox(height: 16),
          KdButton(
            label: 'Continue',
            onPressed: () {
              final problem = _validAsk();
              if (problem != null) {
                _fail(problem);
                throw const ShownError();
              }
              _go(_Step.review);
            },
          ),
        ]);
      case _Step.review:
        if (spec == null) return const SizedBox.shrink();
        return spec.when(
          loading: () => const SkeletonCard(),
          error: (_, _) => ErrorState(message: "Couldn't load the brief form. Check your connection and try again.", onRetry: () async => ref.invalidate(briefSpecProvider('$_skillKey|${_type!.name}'))),
          data: (s) => _review(s, catalog.valueOrNull),
        );
    }
  }

  Widget _review(BriefSpec spec, SkillCatalog? catalog) {
    final price = _priceValue ?? 0;
    final fee = price * 0.1;
    final skill = catalog?.byKey(_skillKey ?? '')?.label ?? _skillKey ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KdCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title.text.trim(), style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text('$skill · ${_type!.label} · ${_inviteOnly ? 'invite only' : 'public'}', style: AppTextStyles.bodySmall),
          const SizedBox(height: 10),
          Text('${formatMoney(price, _currency)}${_type!.priceNote}', style: AppTextStyles.figure.copyWith(color: AppColors.money)),
        ]),
      ),
      const SizedBox(height: 12),
      NoticeCard(
        tone: KdTone.plain,
        icon: Icons.lock_outline_rounded,
        title: 'How the money works',
        body: 'You pay nothing now. When you pick someone, you pay the price plus ${AppBrand.name}\'s 10% (${formatMoney(fee, _currency)}), and it is held until you approve the work. The talent receives the full ${formatMoney(price, _currency)}. Until you pay, nothing starts.',
      ),
      const SizedBox(height: 12),
      const NoticeCard(
        tone: KdTone.plain,
        icon: Icons.shield_outlined,
        title: 'Keep it inside King Domain',
        body: 'No phone numbers, emails, links or payment outside the app, in the job or in messages. A talent never pays anyone, and neither do you outside the app.',
      ),
      const SizedBox(height: 16),
      KdButton(label: widget.editing != null ? 'Send it again' : 'Post the job', busyLabel: 'Posting', onPressed: () => _submit(spec)),
    ]);
  }

  Widget _fieldWidget(BriefField f) {
    switch (f.kind) {
      case BriefKind.text:
        return KdTextField(controller: _field(f.key), label: f.required ? f.label : '${f.label} (optional)', maxLines: (f.max ?? 0) > 200 ? 3 : 1);
      case BriefKind.int:
        return KdTextField(controller: _field(f.key), label: f.required ? f.label : '${f.label} (optional)', keyboardType: TextInputType.number);
      case BriefKind.choice:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in f.options) KdChoiceChip(label: f.key == 'usageRights' ? usageRightsLabel(o) : o, selected: _chosen[f.key] == o, onTap: () => setState(() => _chosen[f.key] = o)),
          ]),
        ]);
      case BriefKind.milestones:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Milestones (2 to 5)', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Each one is funded before it starts and released when you approve it. You can stop after any approved milestone.', style: AppTextStyles.hint),
          const SizedBox(height: 8),
          for (var i = 0; i < _milestones.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KdCard(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: KdTextField(controller: _milestones[i].title, label: 'Milestone ${i + 1}')),
                    if (_milestones.length > 2) IconButton(tooltip: 'Remove milestone ${i + 1}', icon: const Icon(Icons.close_rounded, color: AppColors.text3), onPressed: () => setState(() => _milestones.removeAt(i).dispose())),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: KdTextField(controller: _milestones[i].amount, label: 'Amount', keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: KdTextField(controller: _milestones[i].days, label: 'Days', keyboardType: TextInputType.number)),
                  ]),
                ]),
              ),
            ),
          if (_milestones.length < 5) KdButton.secondary(label: 'Add a milestone', icon: Icons.add_rounded, height: AppDimensions.buttonHeightSm, onPressed: () => setState(() => _milestones.add(_MilestoneRow()))),
        ]);
    }
  }
}

/// The end of the flow: where the job went, and what happens next. Never a dead end.
class _Done extends StatelessWidget {
  final bool held;
  final String? note;
  final bool editing;
  final VoidCallback onDone;
  const _Done({required this.held, required this.note, required this.editing, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 24, AppDimensions.gutter, 40),
        children: [
          RiseIn(
            child: held
                ? NoticeCard(
                    tone: KdTone.warn,
                    icon: Icons.hourglass_top_rounded,
                    title: 'A person is reading it first',
                    body: 'A new client\'s first post is read by a person before it goes live, to keep talents safe. You will be told here and by email as soon as it is live, or what to change.',
                    footnote: note,
                  )
                : const NoticeCard(
                    tone: KdTone.ok,
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Your job is live',
                    body: 'Verified talents can see it now and apply. You can also invite people you find in Talents.',
                  ),
          ),
          const SizedBox(height: 16),
          KdButton(label: 'See my jobs', onPressed: onDone),
        ],
      ),
    );
  }
}
