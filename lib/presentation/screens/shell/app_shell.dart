import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/talent_profile_provider.dart';

/// Post-onboarding app shell — bottom tab nav. Only the Profile tab shows
/// real data (from talentProfileProvider) right now; Jobs and Applications
/// are placeholders until their milestones (03 application-gating UI,
/// 04 contracts) are built out.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    _JobsPlaceholderTab(),
    _ApplicationsPlaceholderTab(),
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

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.slateDim),
            const SizedBox(height: AppDimensions.md),
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.sm),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _JobsPlaceholderTab extends StatelessWidget {
  const _JobsPlaceholderTab();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      icon: Icons.work_outline,
      title: 'Job feed coming next',
      subtitle: 'T4-T6 (Job Feed, Job Detail, Apply) build on this profile.',
    );
  }
}

class _ApplicationsPlaceholderTab extends StatelessWidget {
  const _ApplicationsPlaceholderTab();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      icon: Icons.description_outlined,
      title: 'Applications coming next',
      subtitle: 'T7-T9 track proposals and active contracts.',
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
