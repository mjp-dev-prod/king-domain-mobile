import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/job.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../client/applicants_screen.dart';
import '../client/post_job_screen.dart';
import '../client/client_contract_screen.dart';
import '../../widgets/contract/contract_parts.dart';
import '../contracts/contract_detail_screen.dart';
import '../jobs/job_feed_screen.dart';
import '../payments/fund_contract_screen.dart';
import '../payments/payout_account_screen.dart';
import '../profile/profile_overview_screen.dart';

/// Post-onboarding app shell — bottom tab nav. Jobs and Profile hit the
/// real backend now (jobsProvider, talentProfileProvider — Sprint 4).
/// Phase 2 added a second, client-only nav: same app, same APK, branching
/// on AuthUser.role — see docs/research/BACKEND_SPRINT_PLAN.md's decision
/// to keep one app rather than a separate client build.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const List<Widget> _talentScreens = [
    JobFeedScreen(),
    _ApplicationsTab(),
    _ProfileTab(),
  ];

  static const List<Widget> _clientScreens = [
    _ClientJobsTab(),
    PostJobScreen(),
    _ClientProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final isClient = ref.watch(authProvider).user?.role == 'client';
    final screens = isClient ? _clientScreens : _talentScreens;

    return Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: isClient
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.work_outline),
                  activeIcon: Icon(Icons.work),
                  label: 'My jobs',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  activeIcon: Icon(Icons.add_circle),
                  label: 'Post job',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.work_outline),
                  activeIcon: Icon(Icons.work),
                  label: 'Jobs',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.description_outlined),
                  activeIcon: Icon(Icons.description),
                  label: 'Applications',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }
}

/// C0 — My Jobs (client). Jobs this client posted, filtered client-side
/// from the shared job feed by clientId — there's no dedicated "my posted
/// jobs" backend endpoint, and none is needed for this volume.
class _ClientJobsTab extends ConsumerWidget {
  const _ClientJobsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    final myId = ref.watch(authProvider).user?.id;

    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Could not load your jobs.', style: AppTextStyles.bodyMedium),
      ),
      data: (jobs) {
        final mine = jobs.where((j) => j.clientId == myId).toList();

        if (mine.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.work_outline, size: 40, color: AppColors.slateDim),
                  const SizedBox(height: AppDimensions.md),
                  Text('No jobs posted yet', style: AppTextStyles.h3, textAlign: TextAlign.center),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Post a job from the Post job tab.',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.lg),
            children: [
              for (final job in mine) ...[
                _ClientJobTile(job: job),
                const SizedBox(height: AppDimensions.md),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ClientJobTile extends StatelessWidget {
  final Job job;

  const _ClientJobTile({required this.job});

  @override
  Widget build(BuildContext context) {
    final awarded = job.awardedApplicationId != null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => switch (job.contractStatus) {
              ContractStatus.awaitingPayment => FundContractScreen(jobId: job.id),
              null => ApplicantsScreen(job: job),
              _ => ClientContractScreen(jobId: job.id),
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: AppDimensions.iconSm, color: AppColors.slateDim),
                ],
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(formatNaira(job.budget), style: AppTextStyles.bodySmall.copyWith(color: AppColors.gold)),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  _StatusBadge(status: job.contractStatus),
                  if (job.contractStatus == ContractStatus.awaitingPayment && job.payByAt != null) ...[
                    const SizedBox(width: AppDimensions.sm),
                    Flexible(
                      child: Text(
                        switch (timeLeft(job.payByAt!)) {
                          final left? => 'Pay within $left',
                          null => 'Payment window ended',
                        },
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                      ),
                    ),
                  ],
                  if (!awarded) ...[
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      job.applicationCount == 1 ? '1 applicant' : '${job.applicationCount} applicants',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientProfileTab extends ConsumerWidget {
  const _ClientProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider).user;
    final fullName = authUser?.fullName ?? '';

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.ink2,
          child: Text(
            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
            style: AppTextStyles.h1,
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        Text(fullName.isEmpty ? 'Unnamed' : fullName, style: AppTextStyles.h2),
        Text(
          authUser?.email ?? '',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
        ),
        const SizedBox(height: AppDimensions.xl),
        OutlinedButton(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// T7 — My contracts: jobs awarded to *this* talent. Every job in the feed
/// carries its contract, so filtering on contractStatus alone would list
/// other talents' contracts too — myApplicationStatus 'selected' (mapped to
/// accepted) is what scopes it to this user.
class _ApplicationsTab extends ConsumerWidget {
  const _ApplicationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);

    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Could not load applications.', style: AppTextStyles.bodyMedium),
      ),
      data: (jobs) {
        final withContract = jobs
            .where((j) => j.contractStatus != null && j.applicationStatus == JobApplicationStatus.accepted)
            .toList();

        if (withContract.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 40,
                    color: AppColors.slateDim,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    'No active contracts yet',
                    style: AppTextStyles.h3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Jobs you\'re awarded show up here once a client selects you.',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          children: [
            for (final job in withContract) ...[
              _ApplicationTile(job: job),
              const SizedBox(height: AppDimensions.md),
            ],
          ],
        );
      },
    );
  }
}

class _ApplicationTile extends ConsumerWidget {
  final Job job;

  const _ApplicationTile({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ContractDetailScreen(jobId: job.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(job.clientName, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              _StatusBadge(status: job.contractStatus),
              const SizedBox(width: AppDimensions.sm),
              Icon(
                Icons.chevron_right,
                size: AppDimensions.iconSm,
                color: AppColors.slateDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ContractStatus? status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) => status == null ? const SizedBox.shrink() : contractStatusPill(status!);
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(talentProfileProvider);
    final authUser = ref.watch(authProvider).user;
    final fullName = authUser?.fullName ?? '';

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Could not load profile.', style: AppTextStyles.bodyMedium),
      ),
      data: (profile) => ListView(
        padding: const EdgeInsets.all(AppDimensions.lg),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.ink2,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
              style: AppTextStyles.h1,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            fullName.isEmpty ? 'Unnamed' : fullName,
            style: AppTextStyles.h2,
          ),
          if (profile.headline.isNotEmpty)
            Text(
              profile.headline,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
            ),
          const SizedBox(height: AppDimensions.lg),
          if (!profile.isProfileComplete || profile.proofItems.isEmpty)
            _CompleteProfileBanner(profile: profile)
          else ...[
            if (profile.bio.isNotEmpty) ...[
              Text(profile.bio, style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppDimensions.xl),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Skill categories', style: AppTextStyles.h3),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileOverviewScreen()),
                  ),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: profile.skillCategories.map((c) {
                final isVerified = profile.isVerifiedIn(c);
                final color = isVerified ? AppColors.settled : AppColors.openPending;
                return Chip(
                  label: Text(c),
                  labelStyle: AppTextStyles.bodySmall,
                  backgroundColor: AppColors.ink2,
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  avatar: Icon(
                    isVerified ? Icons.verified : Icons.hourglass_empty,
                    size: AppDimensions.iconSm - 4,
                    color: color,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppDimensions.xl),
          _PayoutAccountRow(account: profile.payoutAccount),
          const SizedBox(height: AppDimensions.xl),
          OutlinedButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _PayoutAccountRow extends StatelessWidget {
  final PayoutAccount? account;

  const _PayoutAccountRow({required this.account});

  @override
  Widget build(BuildContext context) {
    final acct = account;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PayoutAccountScreen()),
      ),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.ink2,
          border: Border.all(color: AppColors.ink3),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_outlined, size: AppDimensions.iconSm, color: AppColors.slateDim),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payout account', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    acct == null
                        ? 'Not set — add one so you can be paid.'
                        : '${acct.bankName ?? 'Bank'} · •••• ${acct.accountNumberLast4}',
                    style: AppTextStyles.bodySmall.copyWith(color: acct == null ? AppColors.openPending : null),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: AppDimensions.iconSm, color: AppColors.slateDim),
          ],
        ),
      ),
    );
  }
}

/// Shown on the Profile tab whenever the profile isn't done or has no
/// proof yet — the entry point into ProfileOverviewScreen now that
/// completing a profile isn't a forced gate before entering the app.
class _CompleteProfileBanner extends StatelessWidget {
  final TalentProfile profile;

  const _CompleteProfileBanner({required this.profile});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileOverviewScreen()),
      ),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.badge_outlined, size: AppDimensions.iconSm, color: AppColors.gold),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your profile',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add your details and proof of work to start applying to jobs.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: AppDimensions.iconSm, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
