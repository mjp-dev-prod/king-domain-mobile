import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_tab_bar.dart';
import '../client/post_job_screen.dart';
import '../jobs/job_feed_screen.dart';
import 'client_jobs_tab.dart';
import 'profile_tabs.dart';
import 'work_tab.dart';

/// Post-sign-in shell with the floating tab bar (prototypes/palette-explorer.html).
/// One app for both roles, branching on AuthUser.role (decision in
/// docs/research/BACKEND_SPRINT_PLAN.md). Tabs keep their scroll position
/// (IndexedStack); the Work / My jobs tab shows how many contracts need you.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isClient = user?.role == 'client';
    final jobs = ref.watch(jobsProvider).valueOrNull ?? const [];

    final List<Widget> screens;
    final List<KdTab> tabs;
    if (isClient) {
      final needs = ClientJobsTab.mine(jobs, user?.id).where((j) => contractNeedsYou(j, forClient: true)).length;
      screens = [ClientJobsTab(onPostJob: () => _go(1)), PostJobScreen(onPosted: () => _go(0)), const ClientProfileTab()];
      tabs = [
        KdTab(icon: Icons.work_outline_rounded, activeIcon: Icons.work_rounded, label: 'My jobs', badge: needs),
        const KdTab(icon: Icons.add_circle_outline_rounded, activeIcon: Icons.add_circle_rounded, label: 'Post'),
        const KdTab(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
      ];
    } else {
      final needs = WorkTab.mine(jobs).where((j) => contractNeedsYou(j, forClient: false)).length;
      screens = [const JobFeedScreen(), WorkTab(onBrowseJobs: () => _go(0)), const TalentProfileTab()];
      tabs = [
        const KdTab(icon: Icons.search_rounded, activeIcon: Icons.search_rounded, label: 'Jobs'),
        KdTab(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Work', badge: needs),
        const KdTab(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
      ];
    }

    return Scaffold(
      extendBody: true, // content scrolls under the floating tab bar
      body: SafeArea(bottom: false, child: IndexedStack(index: _index, children: screens)),
      bottomNavigationBar: KdTabBar(tabs: tabs, index: _index, onChanged: _go),
    );
  }
}
