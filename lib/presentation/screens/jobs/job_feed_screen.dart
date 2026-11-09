import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../../data/models/job.dart';
import '../../../data/models/skill.dart';
import '../../../data/models/skill_submission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../providers/skills_provider.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import '../discovery/invitations_screen.dart';
import '../discovery/saved_searches_screen.dart';
import '../discovery/shortlist_asks_screen.dart';
import '../skills/skills_hub_screen.dart';
import 'job_detail_screen.dart';

/// Whether this talent is verified in the job's skill. The old proof-of-work flow was retired on 2026-11-09 (Victor), so
/// a job from before skills, which has no skill, cannot be applied to.
bool canApplyTo(Job job, {SkillHub? hub}) {
  if (job.skillKey == null) return false;
  return hub?.skills.any((s) => s.skillKey == job.skillKey && s.state == SkillState.verified) ?? false;
}

/// Jobs for you (PRD §3.1 step 7): the talent's verified skills first, server-side filters, saved searches with
/// alerts, and a next step on every empty state.
class JobFeedScreen extends ConsumerStatefulWidget {
  const JobFeedScreen({super.key});

  @override
  ConsumerState<JobFeedScreen> createState() => _JobFeedScreenState();
}

class _JobFeedScreenState extends ConsumerState<JobFeedScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        unawaited(ref.read(feedProvider.notifier).loadMore());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setFilters(FeedFilters f) => ref.read(feedFiltersProvider.notifier).state = f;

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _setFilters(ref.read(feedFiltersProvider).copyWith(query: v)));
  }

  void _clearAll() {
    _search.clear();
    _setFilters(const FeedFilters());
  }

  String _greeting() {
    final h = DateTime.now().hour;
    final part = h < 12 ? 'morning' : h < 17 ? 'afternoon' : 'evening';
    final first = (ref.watch(authProvider).user?.fullName ?? '').trim().split(' ').first;
    return first.isEmpty ? 'Good $part' : 'Good $part, $first';
  }

  Future<void> _saveSearch() async {
    final filters = ref.read(feedFiltersProvider);
    final name = TextEditingController(text: filters.query.trim().isEmpty ? '' : filters.query.trim());
    final saved = await showKdSheet<bool>(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Save this search',
        lead: 'We tell you the moment a new job matches it. Alerts are free, and you can switch them off any time.',
        children: [
          const SizedBox(height: 12),
          KdTextField(controller: name, label: 'Name, e.g. Reels in naira'),
          const SizedBox(height: 14),
          KdButton(
            label: 'Save and alert me',
            busyLabel: 'Saving',
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                KdToast.show(sheet, 'Give it a name so you recognise it.', kind: ToastKind.error);
                throw const ShownError();
              }
              try {
                await ref.read(discoveryActionsProvider).saveSearch(name.text.trim(), filters);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (sheet.mounted) Navigator.of(sheet).pop(true);
            },
          ),
        ],
      ),
    );
    // The sheet is still sliding away: dispose once it is gone, not while it is drawing the field.
    Future<void>.delayed(const Duration(milliseconds: 500), name.dispose);
    if (saved == true && mounted) KdToast.show(context, 'Saved. We will alert you.');
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final filters = ref.watch(feedFiltersProvider);
    final hub = ref.watch(skillHubProvider).valueOrNull;
    final catalog = ref.watch(skillCatalogProvider).valueOrNull;
    final invites = ref.watch(invitationsProvider).valueOrNull?.where((i) => i.open).length ?? 0;
    final asks = ref.watch(shortlistAsksProvider).valueOrNull?.where((a) => a.available == null).length ?? 0;
    bool canApply(Job j) => canApplyTo(j, hub: hub);

    final Widget body;
    final state = feed.valueOrNull;
    if (feed.isLoading && state == null) {
      body = const Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]);
    } else if (feed.hasError && state == null) {
      body = ErrorState(message: "Couldn't load jobs. Check your connection and try again.", onRetry: () => ref.read(feedProvider.notifier).refresh());
    } else if (state!.jobs.isEmpty && !filters.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No jobs match',
        body: 'Nothing fits those filters right now. Save the search and we will tell you the moment one does, or loosen the filters.',
        actionLabel: 'Clear filters',
        onAction: _clearAll,
      );
    } else if (state.jobs.isEmpty) {
      body = EmptyState(
        icon: Icons.work_outline_rounded,
        title: 'No open jobs right now',
        body: 'New jobs appear here as clients post them. Prove another skill to see more of them.',
        actionLabel: 'Your skills',
        onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkillsHubScreen())),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < state.jobs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RiseIn(
                key: ValueKey(state.jobs[i].id),
                delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                child: JobCard(job: state.jobs[i], canApply: canApply(state.jobs[i]), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: state.jobs[i].id)))),
              ),
            ),
          if (state.loadingMore) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))),
          if (state.moreError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: KdButton.secondary(label: "Couldn't load more. Try again", onPressed: () => ref.read(feedProvider.notifier).loadMore()),
            ),
          if (state.nextCursor == null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text("That's every job for now.", textAlign: TextAlign.center, style: AppTextStyles.hint)),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(feedProvider.notifier).refresh(),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 8, AppDimensions.gutter, 120),
        children: [
          ScreenHeader(over: _greeting(), title: 'Jobs for you'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Search jobs',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.text3),
                    suffixIcon: filters.query.isEmpty
                        ? null
                        : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded, color: AppColors.text3), onPressed: () { _search.clear(); _setFilters(filters.copyWith(query: '')); }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IconTile(
                icon: Icons.tune_rounded,
                label: 'Filters',
                active: filters.active.isNotEmpty,
                onTap: () => showKdSheet(context, builder: (sheet) => FeedFilterSheet(initial: filters, onApply: (f) { _setFilters(f); Navigator.of(sheet).pop(); })),
              ),
            ],
          ),
          if (filters.active.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ActiveFilters(filters: filters, onChange: _setFilters, onClear: () => _setFilters(FeedFilters(query: filters.query, skills: filters.skills))),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                Padding(padding: const EdgeInsets.only(right: 8), child: KdChoiceChip(label: 'All skills', selected: filters.skills.isEmpty, onTap: () => _setFilters(filters.copyWith(skills: const {})))),
                for (final s in (catalog?.skills ?? const <Skill>[]).where((s) => s.open))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: KdChoiceChip(
                      label: s.label,
                      selected: filters.skills.contains(s.key),
                      onTap: () => _setFilters(filters.copyWith(skills: filters.skills.contains(s.key) ? ({...filters.skills}..remove(s.key)) : {...filters.skills, s.key})),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Where the rest of discovery lives: what was saved, who invited, who is asking if the talent is free.
          Row(
            children: [
              Expanded(child: _Shortcut(icon: Icons.mail_outline_rounded, label: 'Invitations', count: invites, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvitationsScreen())))),
              const SizedBox(width: 8),
              Expanded(child: _Shortcut(icon: Icons.notifications_none_rounded, label: asks > 0 ? 'Are you free?' : 'Saved searches', count: asks, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => asks > 0 ? const ShortlistAsksScreen() : const SavedSearchesScreen())))),
              if (!filters.isEmpty) ...[
                const SizedBox(width: 8),
                _IconTile(icon: Icons.bookmark_add_outlined, label: 'Save this search and get alerts', active: true, onTap: _saveSearch),
              ],
            ],
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

/// What the Filters button has switched on, said in words, each with a cross to take just that one off. This is what
/// stands in for a bare number on the button: you read the feed's conditions without opening the sheet.
class _ActiveFilters extends StatelessWidget {
  final FeedFilters filters;
  final ValueChanged<FeedFilters> onChange;
  final VoidCallback onClear;
  const _ActiveFilters({required this.filters, required this.onChange, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final active = filters.active;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final f in active)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                onTap: () => onChange(f.without),
                semanticLabel: 'Remove filter: ${f.label}',
                child: Container(
                  padding: const EdgeInsets.only(left: 12, right: 8, top: 7, bottom: 7),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppDimensions.radiusPill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(f.label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.close_rounded, size: 15, color: AppColors.primaryText),
                  ]),
                ),
              ),
            ),
          if (active.length > 1)
            Pressable(
              onTap: onClear,
              semanticLabel: 'Clear all filters',
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), child: Text('Clear all', style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2, fontWeight: FontWeight.w600))),
            ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _IconTile({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: active ? AppColors.primarySoft : AppColors.surface1, borderRadius: BorderRadius.circular(14)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: active ? AppColors.primaryText : AppColors.text2),
          ],
        ),
      ),
    ),
  );
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  const _Shortcut({required this.icon, required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: count > 0 ? '$label, $count waiting' : label,
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: count > 0 ? AppColors.primarySoft : AppColors.surface1, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, size: 18, color: count > 0 ? AppColors.primaryText : AppColors.text2),
        const SizedBox(width: 8),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: count > 0 ? AppColors.primaryText : AppColors.text2))),
        if (count > 0) Text('$count', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryText)),
      ]),
    ),
  );
}

/// The filter sheet. Nothing is sent until Apply, and Clear puts everything back.
class FeedFilterSheet extends StatefulWidget {
  final FeedFilters initial;
  final ValueChanged<FeedFilters> onApply;
  const FeedFilterSheet({super.key, required this.initial, required this.onApply});

  @override
  State<FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends State<FeedFilterSheet> {
  late FeedFilters _f = widget.initial;
  late final _min = TextEditingController(text: _f.budgetMin?.toString() ?? '');
  late final _max = TextEditingController(text: _f.budgetMax?.toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  FeedFilters _withBudget() => _f.copyWith(budgetMin: int.tryParse(_min.text.trim()), budgetMax: int.tryParse(_max.text.trim()));

  @override
  Widget build(BuildContext context) {
    Widget group(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 8), child]),
    );
    return KdSheetBody(
      title: 'Filter jobs',
      children: [
        group('Job type', Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in JobType.values) KdChoiceChip(label: t.label, selected: _f.types.contains(t), onTap: () => setState(() => _f = _f.copyWith(types: _f.types.contains(t) ? ({..._f.types}..remove(t)) : {..._f.types, t}))),
        ])),
        group('Paid in', Wrap(spacing: 8, runSpacing: 8, children: [
          KdChoiceChip(label: 'Any', selected: _f.market == null, onTap: () => setState(() => _f = _f.copyWith(market: null))),
          KdChoiceChip(label: 'Naira', selected: _f.market == 'local', onTap: () => setState(() => _f = _f.copyWith(market: 'local'))),
          KdChoiceChip(label: 'Dollars', selected: _f.market == 'international', onTap: () => setState(() => _f = _f.copyWith(market: 'international'))),
        ])),
        group('Budget', Row(children: [
          Expanded(child: KdTextField(controller: _min, label: 'From', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: KdTextField(controller: _max, label: 'To', keyboardType: TextInputType.number)),
        ])),
        group('Delivery within', Wrap(spacing: 8, runSpacing: 8, children: [
          KdChoiceChip(label: 'Any', selected: _f.deliveryDaysMax == null, onTap: () => setState(() => _f = _f.copyWith(deliveryDaysMax: null))),
          for (final d in const [3, 7, 14, 30]) KdChoiceChip(label: '$d days', selected: _f.deliveryDaysMax == d, onTap: () => setState(() => _f = _f.copyWith(deliveryDaysMax: d))),
        ])),
        group('Only', Column(children: [
          _Switch(label: 'Clients with a verified identity', value: _f.verifiedClient, onChanged: (v) => setState(() => _f = _f.copyWith(verifiedClient: v))),
          _Switch(label: 'Few applicants so far', value: _f.fewApplicants, onChanged: (v) => setState(() => _f = _f.copyWith(fewApplicants: v))),
          _Switch(label: 'My verified skills first', value: _f.forYou, onChanged: (v) => setState(() => _f = _f.copyWith(forYou: v))),
        ])),
        const SizedBox(height: 18),
        KdButton(label: 'Show jobs', onPressed: () => widget.onApply(_withBudget())),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Clear filters', onPressed: () => widget.onApply(FeedFilters(query: _f.query))),
      ],
    );
  }
}

class _Switch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
    Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.primary),
  ]);
}

/// A job in a list. Money in gold (its one job), the apply gate and the cap as plain facts.
class JobCard extends StatelessWidget {
  final Job job;
  final bool canApply;
  final VoidCallback onTap;
  const JobCard({super.key, required this.job, required this.canApply, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final StatusPill fact = switch (job.applicationStatus) {
      JobApplicationStatus.pending => const StatusPill('Applied', tone: KdTone.brand),
      JobApplicationStatus.accepted => const StatusPill('You were selected', tone: KdTone.ok, icon: Icons.check_rounded),
      JobApplicationStatus.rejected => const StatusPill('Not selected'),
      JobApplicationStatus.notApplied =>
        job.paused ? const StatusPill('Paused', tone: KdTone.warn, icon: Icons.pause_circle_outline_rounded)
        : canApply ? const StatusPill('You qualify', tone: KdTone.ok, icon: Icons.verified_outlined)
        : const StatusPill('Needs verified proof', icon: Icons.lock_outline_rounded),
    };
    return KdCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The pills wrap onto a second line on a narrow phone instead of running off the card.
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [StatusPill(job.skillOrCategory, tone: KdTone.brand), if (job.isStructured) StatusPill(job.jobType.label)],
                ),
              ),
              const SizedBox(width: 8),
              Text(formatAgo(job.postedAt), style: AppTextStyles.hint),
            ],
          ),
          const SizedBox(height: 10),
          Text(job.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(job.clientName, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis)),
              fact,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (job.deliveryDays != null) _Meta(icon: Icons.schedule_rounded, text: '${job.deliveryDays} day${job.deliveryDays == 1 ? '' : 's'}'),
                    _Meta(icon: Icons.people_outline_rounded, text: job.isStructured ? '${job.applicationCount} of ${job.applicantCap}' : '${job.applicationCount} applied'),
                    if (job.inviteOnly) const _Meta(icon: Icons.mail_outline_rounded, text: 'Invited'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Flexible so "₦100,000 a week at most" wraps instead of pushing the card wider than the phone.
              Flexible(
                child: Text(
                  '${formatMoney(job.budget, job.currency)}${job.jobType.priceNote}',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.title.copyWith(fontSize: 16, color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 16, color: AppColors.text2), const SizedBox(width: 5), Text(text, style: AppTextStyles.bodySmall)],
  );
}
