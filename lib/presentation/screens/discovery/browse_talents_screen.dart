import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../../data/models/job.dart';
import '../../../data/models/skill.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/skills_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import 'find_someone_screen.dart';
import 'invite_sheet.dart';
import 'saved_talents_screen.dart';
import 'talent_profile_screen.dart';

const _states = ['Lagos', 'Abuja (FCT)', 'Oyo', 'Rivers', 'Ogun', 'Kano', 'Enugu', 'Kaduna', 'Anambra', 'Edo'];

/// Browse talents (PRD §3.2 step 3): recently active first, never a score, newcomers labelled as a fact (D23).
/// As a tab it is the Talents tab; pushed with a job it is where a client invites people to that job.
class BrowseTalentsScreen extends ConsumerStatefulWidget {
  final Job? forJob;
  const BrowseTalentsScreen({super.key, this.forJob});

  @override
  ConsumerState<BrowseTalentsScreen> createState() => _BrowseTalentsScreenState();
}

class _BrowseTalentsScreenState extends ConsumerState<BrowseTalentsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) unawaited(ref.read(talentsProvider.notifier).loadMore());
    });
    // Inviting to a job starts on that job's skill.
    final skill = widget.forJob?.skillKey;
    if (skill != null) {
      Future.microtask(() => ref.read(talentFiltersProvider.notifier).state = TalentFilters(skill: skill));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _set(TalentFilters f) => ref.read(talentFiltersProvider.notifier).state = f;

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(talentFiltersProvider);
    final async = ref.watch(talentsProvider);
    final catalog = ref.watch(skillCatalogProvider).valueOrNull;
    final pushed = widget.forJob != null;
    final job = widget.forJob;

    final Widget body;
    final state = async.valueOrNull;
    if (async.isLoading && state == null) {
      body = const Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]);
    } else if (async.hasError && state == null) {
      body = ErrorState(message: "Couldn't load talents. Check your connection and try again.", onRetry: () => ref.read(talentsProvider.notifier).refresh());
    } else if (state!.talents.isEmpty) {
      body = EmptyState(
        icon: Icons.person_search_outlined,
        title: filters.activeCount > 0 ? 'No talents match' : 'No verified talents yet',
        body: filters.activeCount > 0
            ? 'Try another skill or place, or let us find someone for you: we ask people first and send only those who are free.'
            : 'People appear here once they are verified in a skill. You can also ask us to find someone for you.',
        actionLabel: 'Find someone for me',
        onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FindSomeoneScreen())),
      );
    } else {
      body = Column(children: [
        for (var i = 0; i < state.talents.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RiseIn(
              key: ValueKey(state.talents[i].id),
              delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
              child: TalentCardView(
                talent: state.talents[i],
                onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TalentProfileScreen(talentId: state.talents[i].id, forJob: job))),
                onInvite: job == null ? null : () => showInviteSheet(context, ref, job: job, talent: state.talents[i]),
                onSave: () => _save(state.talents[i]),
              ),
            ),
          ),
        if (state.loadingMore) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))),
        if (state.nextCursor == null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text("That's everyone for now.", textAlign: TextAlign.center, style: AppTextStyles.hint)),
      ]);
    }

    final list = ListView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(AppDimensions.gutter, pushed ? MediaQuery.paddingOf(context).top + 8 : 8, AppDimensions.gutter, 120),
      children: [
        if (pushed)
          ContractHeader(title: 'Invite talents', sub: job!.title, pill: StatusPill(job.skillOrCategory, tone: KdTone.brand))
        else
          const ScreenHeader(title: 'Talents'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _set(ref.read(talentFiltersProvider).copyWith(query: v)));
              },
              textInputAction: TextInputAction.search,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(hintText: 'Search by name or headline', prefixIcon: Icon(Icons.search_rounded, color: AppColors.text3)),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Filters',
            child: Pressable(
              onTap: () => showKdSheet(context, builder: (sheet) => _TalentFilterSheet(initial: filters, onApply: (f) { _set(f); Navigator.of(sheet).pop(); })),
              semanticLabel: 'Filters',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: filters.activeCount - (filters.query.trim().isEmpty ? 0 : 1) > 0 ? AppColors.primarySoft : AppColors.surface1, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.tune_rounded, color: AppColors.text2),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(children: [
            Padding(padding: const EdgeInsets.only(right: 8), child: KdChoiceChip(label: 'All skills', selected: filters.skill == null, onTap: () => _set(filters.copyWith(skill: null)))),
            for (final s in (catalog?.skills ?? const <Skill>[]).where((s) => s.open))
              Padding(padding: const EdgeInsets.only(right: 8), child: KdChoiceChip(label: s.label, selected: filters.skill == s.key, onTap: () => _set(filters.copyWith(skill: s.key)))),
          ]),
        ),
        const SizedBox(height: 12),
        if (!pushed)
          Row(children: [
            Expanded(child: _Shortcut(icon: Icons.bookmark_border_rounded, label: 'Saved talents', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedTalentsScreen())))),
            const SizedBox(width: 8),
            Expanded(child: _Shortcut(icon: Icons.person_search_outlined, label: 'Find someone for me', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FindSomeoneScreen())))),
          ]),
        const SizedBox(height: 16),
        body,
      ],
    );
    return pushed ? Scaffold(body: list) : RefreshIndicator(onRefresh: () => ref.read(talentsProvider.notifier).refresh(), child: list);
  }

  Future<void> _save(TalentCard t) async {
    try {
      await ref.read(discoveryActionsProvider).setSaved(t.id, saved: !t.saved);
      await ref.read(talentsProvider.notifier).refresh();
      if (mounted) KdToast.show(context, t.saved ? 'Removed from saved talents' : 'Saved. Find them in Saved talents.');
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [Icon(icon, size: 18, color: AppColors.text2), const SizedBox(width: 8), Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.text2)))]),
    ),
  );
}

/// A talent in a list: the facts a client weighs, in plain words. No score, no ranking.
class TalentCardView extends StatelessWidget {
  final TalentCard talent;
  final VoidCallback onOpen;
  final VoidCallback? onInvite;
  final VoidCallback? onSave;
  const TalentCardView({super.key, required this.talent, required this.onOpen, this.onInvite, this.onSave});

  @override
  Widget build(BuildContext context) {
    final t = talent;
    return KdCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            UserAvatar(name: t.fullName, photoUrl: t.photoUrl, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.fullName, style: AppTextStyles.title),
                Text(t.headline ?? t.lastActiveText, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (onSave != null)
              Pressable(
                onTap: onSave!,
                semanticLabel: t.saved ? 'Remove ${t.fullName} from saved talents' : 'Save ${t.fullName}',
                child: Padding(padding: const EdgeInsets.all(8), child: Icon(t.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: t.saved ? AppColors.primaryText : AppColors.text3)),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in t.verifiedSkills) StatusPill('Verified: ${s.label}', tone: KdTone.ok, icon: Icons.verified_outlined),
            if (t.newOnKingDomain) StatusPill('New on ${AppBrand.name}', tone: KdTone.brand),
            StatusPill(t.completedJobs == 0 ? 'No completed jobs yet' : '${t.completedJobs} job${t.completedJobs == 1 ? '' : 's'} done'),
            if (t.educationText != null && t.educationText!.isNotEmpty) StatusPill(t.educationText!),
            if (t.regionText != null && t.regionText!.isNotEmpty) StatusPill(t.regionText!),
            StatusPill(t.lastActiveText),
            if (t.responseTime != null) StatusPill('Replies ${t.responseTime}'),
          ]),
          if (onInvite != null) ...[
            const SizedBox(height: 12),
            KdButton(label: 'Invite to this job', icon: Icons.mail_outline_rounded, variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: onInvite),
          ],
        ],
      ),
    );
  }
}

class _TalentFilterSheet extends StatefulWidget {
  final TalentFilters initial;
  final ValueChanged<TalentFilters> onApply;
  const _TalentFilterSheet({required this.initial, required this.onApply});

  @override
  State<_TalentFilterSheet> createState() => _TalentFilterSheetState();
}

class _TalentFilterSheetState extends State<_TalentFilterSheet> {
  late TalentFilters _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    Widget group(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 8), child]),
    );
    return KdSheetBody(
      title: 'Filter talents',
      children: [
        group('Where they are', Wrap(spacing: 8, runSpacing: 8, children: [
          KdChoiceChip(label: 'Anywhere', selected: _f.state == null, onTap: () => setState(() => _f = _f.copyWith(state: null))),
          for (final s in _states) KdChoiceChip(label: s, selected: _f.state == s, onTap: () => setState(() => _f = _f.copyWith(state: s))),
        ])),
        group('How they describe themselves', Wrap(spacing: 8, runSpacing: 8, children: [
          KdChoiceChip(label: 'Any', selected: _f.education == null, onTap: () => setState(() => _f = _f.copyWith(education: null))),
          for (final e in const [('student', 'Student'), ('graduate', 'Graduate'), ('trained', 'Trained'), ('selfTaught', 'Self-taught')])
            KdChoiceChip(label: e.$2, selected: _f.education == e.$1, onTap: () => setState(() => _f = _f.copyWith(education: e.$1))),
        ])),
        group('Experience here', Row(children: [
          Expanded(child: Text('Has completed a job on ${AppBrand.name}', style: AppTextStyles.bodyMedium)),
          Switch(value: _f.hasCompleted, onChanged: (v) => setState(() => _f = _f.copyWith(hasCompleted: v)), activeTrackColor: AppColors.primary),
        ])),
        const SizedBox(height: 18),
        KdButton(label: 'Show talents', onPressed: () => widget.onApply(_f)),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Clear filters', onPressed: () => widget.onApply(TalentFilters(skill: _f.skill, query: _f.query))),
      ],
    );
  }
}
