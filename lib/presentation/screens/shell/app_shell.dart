import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../contracts/contract_detail_screen.dart';
import '../jobs/job_feed_screen.dart';

/// Post-onboarding app shell — bottom tab nav. Jobs and Profile hit the
/// real backend now (jobsProvider, talentProfileProvider — Sprint 4).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _screens = [
    JobFeedScreen(),
    _ApplicationsTab(),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_index]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
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

/// T7 — My Applications. A job only shows up here once this talent has
/// actually applied (backend has no "my application status" embedded on
/// the job list — see jobs_provider.dart's fetchOne/listApplications — so
/// this tab shows jobs with a contract, i.e. jobs this talent was awarded).
/// Awarding is a client-side action (backend jobsRoutes.js's /award route)
/// with no client UI in this app yet — see BACKEND_SPRINT_PLAN.md Sprint 6.
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
        final withContract = jobs.where((j) => j.contractStatus != null).toList();

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
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ContractStatus.funded => ('Funded', AppColors.openPending),
      ContractStatus.inProgress => ('In progress', AppColors.openPending),
      ContractStatus.submitted => ('Submitted', AppColors.openPending),
      ContractStatus.approved => ('Approved', AppColors.settled),
      null => ('', AppColors.slateDim),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
    );
  }
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
          Text(
            profile.headline,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text(profile.bio, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppDimensions.xl),
          Text('Skill categories', style: AppTextStyles.h3),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: profile.skillCategories.map((c) {
              final verifiedCount = profile.proofItems
                  .where((p) => p.category == c && p.status.name == 'verified')
                  .length;
              final isVerified = verifiedCount > 0;
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
