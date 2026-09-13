import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../contracts/contract_detail_screen.dart';
import '../jobs/job_feed_screen.dart';

/// Post-onboarding app shell — bottom tab nav. Jobs and Profile show real
/// state now (jobsProvider, talentProfileProvider); Applications is a
/// placeholder until T7-T9 (contracts, Milestone 04) are built out.
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

/// T7 — My Applications. Tracks proposals submitted via T6; once a job is
/// accepted, tapping it opens the contract flow (ContractDetailScreen) —
/// the wedge's actual test (see docs/core/vision-vs-research-reconciliation.md
/// §2). Pre-hire messaging with interested clients waits on the real-time-chat
/// hosting migration decided in Milestone 03.
class _ApplicationsTab extends ConsumerWidget {
  const _ApplicationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref
        .watch(jobsProvider)
        .where((j) => j.applicationStatus != JobApplicationStatus.notApplied)
        .toList();

    if (applied.isEmpty) {
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
                'No applications yet',
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'Applications you submit from the Jobs tab show up here.',
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
        for (final job in applied) ...[
          _ApplicationTile(job: job),
          const SizedBox(height: AppDimensions.md),
        ],
      ],
    );
  }
}

class _ApplicationTile extends ConsumerWidget {
  final Job job;

  const _ApplicationTile({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAccepted = job.applicationStatus == JobApplicationStatus.accepted;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () {
          if (isAccepted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ContractDetailScreen(jobId: job.id),
              ),
            );
          } else if (job.applicationStatus == JobApplicationStatus.pending) {
            // No client app exists yet — this simulates the founding team
            // manually matching and funding the job (see jobs_provider.dart).
            ref.read(jobsProvider.notifier).simulateAcceptAndFund(job.id);
          }
        },
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
                    if (job.applicationStatus == JobApplicationStatus.pending) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Tap to simulate client acceptance',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.slateDim,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusBadge(status: job.applicationStatus),
              if (isAccepted) ...[
                const SizedBox(width: AppDimensions.sm),
                Icon(
                  Icons.chevron_right,
                  size: AppDimensions.iconSm,
                  color: AppColors.slateDim,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final JobApplicationStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      JobApplicationStatus.pending => ('Pending', AppColors.openPending),
      JobApplicationStatus.accepted => ('Accepted', AppColors.settled),
      JobApplicationStatus.rejected => ('Rejected', AppColors.slateDim),
      JobApplicationStatus.notApplied => ('', AppColors.slateDim),
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
    final profile = ref.watch(talentProfileProvider);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.ink2,
          child: Text(
            profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
            style: AppTextStyles.h1,
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        Text(
          profile.fullName.isEmpty ? 'Unnamed' : profile.fullName,
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
      ],
    );
  }
}
