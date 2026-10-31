import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_image.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import '../payments/fund_contract_screen.dart';
import '../discovery/browse_talents_screen.dart';
import '../discovery/talent_profile_screen.dart';
import 'applicant_panel_card.dart';
import 'post_job_flow.dart';
import 'post_job_screen.dart';

/// C2 — Applicants and the single award (prototypes/palette-explorer.html,
/// screen 05). Real signals only, everyone on equal footing, in the order
/// they applied: no score, no "best match" (docs/core/correction-talent-
/// discovery-screen.md). Awarding is atomic server-side (one selected, the
/// rest not selected, contract created awaiting payment), then payment.
class ApplicantsScreen extends ConsumerStatefulWidget {
  final Job job;

  const ApplicantsScreen({super.key, required this.job});

  @override
  ConsumerState<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends ConsumerState<ApplicantsScreen> {
  late Future<List<JobApplication>> _future = _load();

  Future<List<JobApplication>> _load() => ref.read(jobsProvider.notifier).listApplications(widget.job.id);

  @override
  Widget build(BuildContext context) {
    // The live copy, so an edit or a close shows here without reopening the screen.
    final job = ref.watch(jobsProvider).valueOrNull?.where((j) => j.id == widget.job.id).firstOrNull ?? widget.job;
    final awarded = job.awardedApplicationId != null;
    final closed = job.closed;
    return Scaffold(
      body: FutureBuilder<List<JobApplication>>(
        future: _future,
        builder: (context, snap) {
          final Widget body;
          if (snap.connectionState != ConnectionState.done) {
            body = const Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard()]);
          } else if (snap.hasError) {
            body = ErrorState(
              message: 'Couldn\'t load applicants. Check your connection and try again.',
              onRetry: () async => setState(() => _future = _load()),
            );
          } else if (snap.data!.isEmpty) {
            body = closed
                ? const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'Nobody applied',
                    body: 'Nobody applied before the job was closed.',
                  )
                : const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No applicants yet',
                    body: 'Students verified in this category can apply. You\'ll see each one here with their verified work.',
                  );
          } else {
            final apps = snap.data!;
            body = Column(
              children: [
                for (var i = 0; i < apps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RiseIn(
                      delay: Duration(milliseconds: 50 * i.clamp(0, 6)),
                      child: apps[i].panel != null
                          ? ApplicantPanelCard(
                              app: apps[i],
                              awardedHere: apps[i].id == job.awardedApplicationId,
                              canAct: !awarded && !closed,
                              onPick: () { _confirmAward(apps[i]); },
                              onShortlist: () => _shortlist(apps[i]),
                              onDecline: () => _confirmDecline(apps[i]),
                              onOpenProfile: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TalentProfileScreen(talentId: apps[i].talentId, forJob: job))),
                            )
                          : _ApplicantCard(
                              app: apps[i],
                              awardedHere: apps[i].id == job.awardedApplicationId,
                              canAward: !awarded && !closed,
                              onAward: () { _confirmAward(apps[i]); },
                            ),
                    ),
                  ),
              ],
            );
          }
          final count = snap.data?.length ?? job.applicationCount;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
              children: [
                ContractHeader(
                  title: job.title,
                  sub: '${formatNaira(job.budget)} · ${job.deliveryDays == null ? job.category : '${job.deliveryDays} days to deliver'}',
                  pill: closed ? const StatusPill('Closed') : StatusPill('$count applied'),
                  // Awarded and closed jobs can't be changed: the menu is only for open ones.
                  action: awarded || closed ? null : _menuButton(job),
                ),
                const SizedBox(height: 12),
                KdCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          closed
                              ? 'You closed this job. Applicants can see that it was closed.'
                              : awarded
                                  ? 'You picked someone for this job.'
                                  : 'Shown in the order they applied. ${AppBrand.name} doesn\'t rank applicants: compare their verified work and pick.',
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                if (job.isStructured && !awarded && !closed) ...[const SizedBox(height: 12), _capBanner(job, snap.data?.length ?? job.applicationCount)],
                const SizedBox(height: 12),
                body,
              ],
            ),
          );
        },
      ),
    );
  }

  /// The soft cap (D21): how many have applied, and when it is paused, the way to reopen.
  Widget _capBanner(Job job, int count) {
    final cap = ref.read(jobsProvider.notifier).capFor(job.id);
    final paused = cap?.paused ?? job.paused;
    final reason = cap?.reason ?? job.pausedReason;
    return Column(
      children: [
        if (paused)
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.pause_circle_outline_rounded,
            title: 'Applications are paused',
            body: reason == 'applicants'
                ? '${job.applicantCap} people have applied, so new applications are paused while you look at them. Reopening lets another ${job.applicantCap} apply.'
                : 'This job has been open for 5 days, so new applications are paused. Reopening starts the 5 days again.',
            actions: [KdButton(label: 'Reopen applications', busyLabel: 'Reopening', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: _reopen)],
          )
        else
          Row(children: [Expanded(child: Text('$count of ${job.applicantCap} applicants. Applications pause at ${job.applicantCap} or after 5 days.', style: AppTextStyles.hint))]),
        const SizedBox(height: 10),
        KdButton.secondary(label: 'Invite talents', icon: Icons.person_add_alt_1_outlined, height: AppDimensions.buttonHeightSm, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BrowseTalentsScreen(forJob: job)))),
      ],
    );
  }

  Future<void> _reopen() async {
    try {
      await ref.read(discoveryActionsProvider).reopen(widget.job.id);
      setState(() => _future = _load());
      if (mounted) KdToast.show(context, 'Applications are open again.');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'premium_required') {
        showKdSheet(
          context,
          builder: (sheet) => KdSheetBody(
            title: 'Reopening is a premium feature',
            lead: 'Getting more applicants after the first ${widget.job.applicantCap} is part of premium. Premium is coming to the app soon. Until then you can still pick from the people who applied.',
            children: [const SizedBox(height: 14), KdButton(label: 'Got it', onPressed: () => Navigator.of(sheet).pop())],
          ),
        );
      } else {
        KdToast.show(context, e.message, kind: ToastKind.error);
      }
      throw const ShownError();
    }
  }

  Future<void> _shortlist(JobApplication app) async {
    try {
      await ref.read(discoveryActionsProvider).shortlistApplicant(widget.job.id, app.id, on: app.status != 'shortlisted');
      setState(() => _future = _load());
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  void _confirmDecline(JobApplication app) {
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Decline ${app.talentName}?',
        lead: 'They are told that you chose not to go ahead, by notification and email. This can\'t be undone.',
        children: [
          const SizedBox(height: 18),
          KdButton(
            label: 'Decline',
            busyLabel: 'Declining',
            variant: KdButtonVariant.danger,
            onPressed: () async {
              try {
                await ref.read(discoveryActionsProvider).declineApplicant(widget.job.id, app.id);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!mounted || !sheet.mounted) return;
              Navigator.of(sheet).pop();
              setState(() => _future = _load());
              if (!context.mounted) return;
              KdToast.show(context, 'Declined. ${app.talentName.split(' ').first} has been told.');
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep them', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  Widget _menuButton(Job job) => Tooltip(
        message: 'Manage this job',
        child: Pressable(
          onTap: () => _openMenu(job),
          semanticLabel: 'Manage this job',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.more_horiz_rounded, color: AppColors.text),
          ),
        ),
      );

  /// Edit (only while nobody has applied: the server locks the terms then) and Close.
  void _openMenu(Job job) {
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Manage this job',
        children: [
          const SizedBox(height: 14),
          if (job.applicationCount == 0)
            KdButton(
              label: 'Edit job',
              variant: KdButtonVariant.soft,
              onPressed: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => job.isStructured ? PostJobFlow(editing: job, onPosted: () => Navigator.of(context).pop()) : PostJobScreen(editing: job)));
              },
            )
          else
            const NoticeCard(
              tone: KdTone.plain,
              icon: Icons.lock_outline_rounded,
              title: 'Terms are locked',
              body: 'Someone has already applied, so the details can\'t change under them. Close it and post a new one to change them.',
            ),
          const SizedBox(height: 10),
          KdButton(
            label: 'Close job',
            variant: KdButtonVariant.danger,
            onPressed: () {
              Navigator.of(sheet).pop();
              _confirmClose(job);
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Never mind', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  void _confirmClose(Job job) {
    final n = job.applicationCount;
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Close this job?',
        lead: n == 0
            ? 'Nobody has applied yet. A closed job can\'t be undone: post a new one if you change your mind.'
            : '$n applicant${n == 1 ? '' : 's'} will see that it was closed. A closed job can\'t be undone: post a new one if you change your mind.',
        children: [
          const SizedBox(height: 18),
          KdButton(
            label: 'Close job',
            busyLabel: 'Closing',
            variant: KdButtonVariant.danger,
            onPressed: () async {
              final sheetNav = Navigator.of(sheet);
              final nav = Navigator.of(context);
              try {
                await ref.read(jobsProvider.notifier).closeJob(job.id);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!mounted) return;
              sheetNav.pop();
              KdToast.show(context, 'Job closed.');
              nav.pop();
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep it open', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  void _confirmAward(JobApplication app) {
    final job = widget.job;
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Pick ${app.talentName}?',
        lead: 'Everyone else is told they weren\'t selected. You then have 24 hours to pay the '
            '${formatNaira(job.budget)} budget plus ${AppBrand.name}\'s fee, held until you approve the work. '
            'If you don\'t pay in time, the award is cancelled and the others are back in the running.',
        children: [
          const SizedBox(height: 18),
          KdButton(
            label: 'Pick ${app.talentName}',
            busyLabel: 'Picking',
            onPressed: () async {
              final sheetNav = Navigator.of(sheet);
              final nav = Navigator.of(context);
              try {
                await ref.read(jobsProvider.notifier).awardApplication(job.id, app.id);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (!mounted) return;
              sheetNav.pop();
              nav.pushReplacement(MaterialPageRoute(builder: (_) => FundContractScreen(jobId: job.id)));
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep looking', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  final JobApplication app;
  final bool awardedHere;
  final bool canAward;
  final VoidCallback onAward;
  const _ApplicantCard({required this.app, required this.awardedHere, required this.canAward, required this.onAward});

  @override
  Widget build(BuildContext context) {
    final s = app.signals;
    final notSelected = app.status == 'notSelected';
    return Opacity(
      opacity: notSelected ? .55 : 1,
      child: KdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(name: app.talentName, photoUrl: app.talentPhotoUrl, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.talentName, style: AppTextStyles.title),
                      Text(s.headline ?? 'Applied ${formatAgo(app.createdAt)}', style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (awardedHere) const StatusPill('Picked', tone: KdTone.ok, icon: Icons.check_rounded),
                if (notSelected) const StatusPill('Not selected'),
              ],
            ),
            if (s.proof.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: i < s.proof.length ? WorkImage(url: s.proof[i].fileUrl, radius: AppDimensions.radiusSm) : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                s.verifiedInCategory
                    ? const StatusPill('Verified in this category', tone: KdTone.ok, icon: Icons.verified_outlined)
                    : const StatusPill('Not verified in this category'),
                StatusPill(s.jobsCompleted == 0 ? 'New to ${AppBrand.name}' : '${s.jobsCompleted} job${s.jobsCompleted == 1 ? '' : 's'} done'),
              ],
            ),
            if (canAward) ...[
              const SizedBox(height: 14),
              KdButton(label: 'Pick ${app.talentName.split(' ').first}', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: onAward),
            ],
          ],
        ),
      ),
    );
  }
}
