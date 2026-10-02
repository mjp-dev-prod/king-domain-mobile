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
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_image.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import '../payments/fund_contract_screen.dart';

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
    final job = widget.job;
    final awarded = job.awardedApplicationId != null;
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
            body = const EmptyState(
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
                      child: _ApplicantCard(
                        app: apps[i],
                        awardedHere: apps[i].id == job.awardedApplicationId,
                        canAward: !awarded,
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
                  pill: StatusPill('$count applied'),
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
                          awarded
                              ? 'You picked someone for this job.'
                              : 'Shown in the order they applied. ${AppBrand.name} doesn\'t rank applicants: compare their verified work and pick.',
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                body,
              ],
            ),
          );
        },
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
                InitialsAvatar(name: app.talentName, size: 46),
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
