import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/api_client.dart';
import '../../../data/models/packages.dart';
import '../../providers/packages_provider.dart';
import '../../providers/skills_provider.dart';
import '../../widgets/brief/brief_form.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/reputation_widgets.dart';
import '../../widgets/kit/status_pill.dart';
import '../../widgets/kit/kd_auth.dart';
import 'package_orders_screen.dart';

/// Ready-made packages for a client to buy (D4): by skill, recently active first, the price in gold. No score and no
/// paid place; every package in a skill answers the same questions so they can be compared.
class PackageBrowseScreen extends ConsumerStatefulWidget {
  const PackageBrowseScreen({super.key});

  @override
  ConsumerState<PackageBrowseScreen> createState() => _PackageBrowseScreenState();
}

class _PackageBrowseScreenState extends ConsumerState<PackageBrowseScreen> {
  String? _skill;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(skillCatalogProvider).valueOrNull;
    final async = ref.watch(packageBrowseProvider(_skill));
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(packageBrowseProvider(_skill)),
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
          children: [
            const ContractHeader(title: 'Packages', sub: 'Ready-made offers from verified talents', pill: StatusPill('Fixed price', tone: KdTone.brand)),
            const SizedBox(height: 12),
            if (catalog != null)
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  Padding(padding: const EdgeInsets.only(right: 8), child: KdChoiceChip(label: 'All skills', selected: _skill == null, onTap: () => setState(() => _skill = null))),
                  for (final s in catalog.skills.where((s) => s.open)) Padding(padding: const EdgeInsets.only(right: 8), child: KdChoiceChip(label: s.label, selected: _skill == s.key, onTap: () => setState(() => _skill = s.key))),
                ]),
              ),
            const SizedBox(height: 12),
            KdButton.secondary(label: 'Your orders', icon: Icons.inbox_outlined, height: AppDimensions.buttonHeightSm, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackageOrdersScreen()))),
            const SizedBox(height: 12),
            async.when(
              loading: () => const Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
              error: (_, _) => ErrorState(message: 'Couldn\'t load the packages. Check your connection and try again.', onRetry: () async => ref.invalidate(packageBrowseProvider(_skill))),
              data: (page) {
                if (page.packages.isEmpty) {
                  return const EmptyState(icon: Icons.inventory_2_outlined, title: 'No packages here yet', body: 'Talents publish packages once they are verified in a skill. In the meantime you can post the job and let them come to you.');
                }
                return Column(children: [
                  for (var i = 0; i < page.packages.length; i++)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: RiseIn(delay: Duration(milliseconds: 40 * i.clamp(0, 6)), child: _PackageTile(p: page.packages[i]))),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  final PackageItem p;
  const _PackageTile({required this.p});

  @override
  Widget build(BuildContext context) {
    final t = p.talent;
    return Pressable(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PackageDetailScreen(packageId: p.id))),
      semanticLabel: '${p.title}, ${formatMoney(p.price, p.currency)}',
      child: KdCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (t != null) UserAvatar(name: t.fullName, photoUrl: t.photoUrl, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t?.fullName ?? 'Talent', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${p.skillLabel} · ${t?.lastActiveText ?? ''}', style: AppTextStyles.hint, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            StatusPill(p.tierLabel),
          ]),
          const SizedBox(height: 10),
          Text(p.title, style: AppTextStyles.title),
          const SizedBox(height: 2),
          Text(p.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2)),
          const SizedBox(height: 10),
          // Side by side when they fit, the terms under the price when they don't: neither gets cut off.
          SizedBox(
            width: double.infinity,
            child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 2, children: [
              Text(formatMoney(p.price, p.currency), style: AppTextStyles.h3.copyWith(color: AppColors.money)),
              Text('${p.deliveryDays} days · ${p.revisions} round${p.revisions == 1 ? '' : 's'} of changes', style: AppTextStyles.hint),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One package, the talent behind it, and the rest of the brief the client fills in to order it.
class PackageDetailScreen extends ConsumerStatefulWidget {
  final String packageId;
  const PackageDetailScreen({super.key, required this.packageId});

  @override
  ConsumerState<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends ConsumerState<PackageDetailScreen> {
  final _answers = BriefAnswers();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _answers.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _order(PackageDetail d) async {
    final problem = _answers.validate(d.formFields);
    if (problem != null) {
      setState(() => _error = problem);
      throw const ShownError();
    }
    setState(() => _error = null);
    try {
      await ref.read(packageActionsProvider).order(d.package.id, brief: _answers.toJson(d.formFields), note: _note.text.trim().isEmpty ? null : _note.text.trim());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Sent. ${d.talent.fullName.split(' ').first} has 48 hours to accept');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PackageOrdersScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(packageDetailProvider(widget.packageId));
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (e, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: e is ApiException && e.status == 404 ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No longer available', body: 'The talent paused or removed this package. You can look at others.') : ErrorState(message: 'Couldn\'t load this package. Check your connection and try again.', onRetry: () async => ref.invalidate(packageDetailProvider(widget.packageId))))),
          ]),
        ),
        data: (d) {
          final p = d.package;
          return ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
            children: [
              ContractHeader(title: p.title, sub: '${p.skillLabel} · by ${d.talent.fullName}', pill: StatusPill(p.tierLabel, tone: KdTone.brand)),
              const SizedBox(height: 12),
              KdCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(formatMoney(p.price, p.currency), style: AppTextStyles.h2.copyWith(color: AppColors.money)),
                  const SizedBox(height: 6),
                  Text(p.summary, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 12),
                  _fact('Included', p.included),
                  _fact('Delivered in', '${p.deliveryDays} days'),
                  _fact('Changes', '${p.revisions} round${p.revisions == 1 ? '' : 's'} included'),
                  if (p.scopeLines.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    // The skill's own terms, e.g. pages and features for a website. Labels can be long, so each sits above its answer.
                    for (final l in p.scopeLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.label, style: AppTextStyles.hint),
                          Text(l.value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
                        ]),
                      ),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              Text('About ${d.talent.fullName.split(' ').first}', style: AppTextStyles.title),
              const SizedBox(height: 8),
              TalentReputationSection(reputation: d.reputation, canReport: false),
              const SizedBox(height: 18),
              Text('What they need from you', style: AppTextStyles.title),
              const SizedBox(height: 4),
              Text('The package already covers what is included. Tell them the rest.', style: AppTextStyles.hint),
              const SizedBox(height: 10),
              for (final f in d.formFields) ...[BriefFieldInput(field: f, answers: _answers, onChanged: () => setState(() {})), const SizedBox(height: 10)],
              KdTextField(controller: _note, label: 'Anything else? (optional)', maxLines: 3),
              const SizedBox(height: 14),
              NoticeCard(
                tone: KdTone.plain,
                icon: Icons.lock_outline_rounded,
                title: 'You pay nothing now',
                body: '${d.talent.fullName.split(' ').first} has 48 hours to accept. When they do, you pay ${formatMoney(p.price, p.currency)} plus ${AppBrand.name}\'s 10% (${formatMoney(d.fee, p.currency)}) and it is held until you approve the work. The talent receives the full ${formatMoney(p.price, p.currency)}. A talent never asks you to pay them directly.',
              ),
              if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))],
              const SizedBox(height: 14),
              KdButton(label: 'Order this package', busyLabel: 'Sending', icon: Icons.shopping_bag_outlined, onPressed: () => _order(d)),
            ],
          );
        },
      ),
    );
  }

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 96, child: Text(label, style: AppTextStyles.hint)),
      Expanded(child: Text(value, style: AppTextStyles.bodySmall)),
    ]),
  );
}
