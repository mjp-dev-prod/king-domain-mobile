import '../../widgets/kit/info_tip.dart';
import '../../../core/constants/glossary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/api_client.dart';
import '../../../data/models/packages.dart';
import '../../providers/packages_provider.dart';
import '../../../data/models/discovery.dart' show BriefField;
import '../../widgets/brief/brief_form.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import '../skills/skills_hub_screen.dart';
import 'package_orders_screen.dart';

/// A talent's ready-made packages (D4): up to three tiers in each skill they are verified in, with the skill's own
/// fields (pages and features for a website, platforms and posts for social media) so clients can compare them.
/// Clients order one, and the talent has 48 hours to take it.
class MyPackagesScreen extends ConsumerWidget {
  const MyPackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPackagesProvider);
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: ErrorState(message: 'Couldn\'t load your packages. Check your connection and try again.', onRetry: () async => ref.invalidate(myPackagesProvider)))),
          ]),
        ),
        data: (mine) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPackagesProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
            children: [
              ContractHeader(title: 'Your packages', sub: 'Ready-made offers clients can buy', pill: StatusPill('${mine.packages.length} published', tone: KdTone.brand)),
              const SizedBox(height: 12),
              KdButton.secondary(
                label: 'Orders waiting for you',
                icon: Icons.inbox_outlined,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackageOrdersScreen())),
              ),
              const SizedBox(height: 12),
              if (mine.skills.isEmpty)
                EmptyState(
                  icon: Icons.verified_outlined,
                  title: 'Get verified first',
                  body: 'You can publish a package in a skill once you are verified in it. Verified skills are what clients trust.',
                  actionLabel: 'Go to your skills',
                  onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkillsHubScreen())),
                )
              else
                for (final s in mine.skills) ...[
                  Padding(padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4), child: Text(s.label, style: AppTextStyles.title)),
                  for (final tier in mine.tiers) RiseIn(child: Padding(padding: const EdgeInsets.only(bottom: 8), child: _TierCard(skillKey: s.skillKey, skillLabel: s.label, tier: tier, fields: s.fields, existing: mine.at(s.skillKey, tier)))),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

String _tierName(String tier) => switch (tier) { 'basic' => 'Basic', 'standard' => 'Standard', _ => 'Premium' };

class _TierCard extends ConsumerWidget {
  final String skillKey;
  final String skillLabel;
  final String tier;
  final List<BriefField> fields;
  final PackageItem? existing;
  const _TierCard({required this.skillKey, required this.skillLabel, required this.tier, required this.fields, required this.existing});

  Future<void> _edit(BuildContext context) => showKdSheet(context, builder: (_) => _EditorSheet(skillKey: skillKey, tier: tier, fields: fields, existing: existing));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = existing;
    if (p == null) {
      return Pressable(
        onTap: () => _edit(context),
        semanticLabel: 'Add the ${_tierName(tier)} package for $skillLabel',
        child: KdCard(child: Row(children: [
          const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryText),
          const SizedBox(width: 12),
          Expanded(child: Text('Add a ${_tierName(tier)} package', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
        ])),
      );
    }
    return KdCard(
      tone: p.needsUpdate ? KdTone.warn : p.paused ? KdTone.plain : KdTone.ok,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${_tierName(tier)}: ${p.title}', style: AppTextStyles.title)),
          if (p.needsUpdate)
            const StatusPill('Hidden', tone: KdTone.warn)
          else if (p.paused)
            const StatusPill('Paused')
          else
            const StatusPill('Live', tone: KdTone.ok),
        ]),
        const SizedBox(height: 4),
        Text(formatMoney(p.price, p.currency), style: AppTextStyles.bodySmall.copyWith(color: AppColors.money, fontWeight: FontWeight.w700)),
        Text('${p.deliveryDays} days · ${p.revisions} round${p.revisions == 1 ? '' : 's'} of changes', style: AppTextStyles.bodySmall),
        const SizedBox(height: 4),
        Text(p.summary, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2)),
        if (p.needsUpdate) ...[
          const SizedBox(height: 10),
          const NoticeCard(
            tone: KdTone.warn,
            icon: Icons.edit_note_rounded,
            title: 'Clients can\'t see this until you update it',
            body: 'Packages now describe what is in them the way your skill does, for example pages and features for a website, instead of "how many" and "formats". Tap Update and answer those, and it goes live again.',
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (p.needsUpdate)
            KdButton(label: 'Update', height: AppDimensions.buttonHeightSm, onPressed: () => _edit(context))
          else
            KdButton.secondary(label: 'Edit', height: AppDimensions.buttonHeightSm, onPressed: () => _edit(context)),
          KdButton.secondary(
            label: p.paused ? 'Put it live' : 'Pause it',
            height: AppDimensions.buttonHeightSm,
            onPressed: () async {
              try {
                await ref.read(packageActionsProvider).setPaused(p.id, !p.paused);
              } on ApiException catch (e) {
                if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
              }
            },
          ),
          KdButton.secondary(
            label: 'Remove',
            height: AppDimensions.buttonHeightSm,
            onPressed: () async {
              try {
                await ref.read(packageActionsProvider).remove(p.id);
                if (context.mounted) KdToast.show(context, 'Removed');
              } on ApiException catch (e) {
                if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
              }
            },
          ),
        ]),
      ]),
    );
  }
}

class _EditorSheet extends ConsumerStatefulWidget {
  final String skillKey;
  final String tier;
  final List<BriefField> fields;
  final PackageItem? existing;
  const _EditorSheet({required this.skillKey, required this.tier, required this.fields, required this.existing});

  @override
  ConsumerState<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends ConsumerState<_EditorSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _summary = TextEditingController(text: widget.existing?.summary ?? '');
  late final _included = TextEditingController(text: widget.existing?.included ?? '');
  late final _price = TextEditingController(text: widget.existing == null ? '' : widget.existing!.price.round().toString());
  late final _answers = BriefAnswers(widget.existing?.scope);
  late int _days = widget.existing?.deliveryDays ?? 5;
  late int _revisions = widget.existing?.revisions ?? 2;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _summary, _included, _price]) {
      c.dispose();
    }
    _answers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.replaceAll(',', '').trim());
    if (price == null) {
      setState(() => _error = 'Write the price as a number.');
      throw const ShownError();
    }
    final problem = _answers.validate(widget.fields);
    if (problem != null) {
      setState(() => _error = problem);
      throw const ShownError();
    }
    setState(() => _error = null);
    try {
      await ref.read(packageActionsProvider).save(widget.skillKey, widget.tier, title: _title.text.trim(), summary: _summary.text.trim(), included: _included.text.trim(), scope: _answers.toJson(widget.fields), price: price, deliveryDays: _days, revisions: _revisions);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    KdToast.show(context, widget.existing == null ? 'Published' : 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: '${_tierName(widget.tier)} package',
      lead: 'What a client gets, in the same questions every package in this skill answers, so they can compare. No contact details or links: everything stays inside King Domain.',
      children: [
        const SizedBox(height: 12),
        KdTextField(controller: _title, label: 'Title', textInputAction: TextInputAction.next),
        const SizedBox(height: 10),
        KdTextField(controller: _summary, label: 'In one or two sentences', maxLines: 2),
        const SizedBox(height: 10),
        KdTextField(controller: _included, label: 'What is included', maxLines: 3),
        const SizedBox(height: 10),
        for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 10), child: BriefFieldInput(field: f, answers: _answers, onChanged: () => setState(() {}))),
        KdTextField(controller: _price, label: 'Price (₦)', keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        Text('Delivered in', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DayStepper(value: _days, min: 1, max: 60, onChanged: (v) => setState(() => _days = v)),
        const SizedBox(height: 12),
        TitleWithTip('Rounds of changes included', Glossary.changeRounds, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [for (final r in [0, 1, 2]) KdChoiceChip(label: '$r', selected: _revisions == r, onTap: () => setState(() => _revisions = r))]),
        if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))],
        const SizedBox(height: 16),
        KdButton(label: widget.existing == null ? 'Publish' : 'Save', busyLabel: 'Saving', onPressed: _save),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
