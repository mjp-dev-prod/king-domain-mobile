import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/push_gateway.dart';
import '../../providers/push_service.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_tab_bar.dart';
import '../../widgets/kit/kd_toast.dart';
import '../client/post_job_flow.dart';
import '../discovery/browse_talents_screen.dart';
import '../messages/messages_screen.dart';
import '../../providers/messaging_provider.dart';
import '../jobs/job_feed_screen.dart';
import '../profile/notifications_sheet.dart';
import 'client_jobs_tab.dart';
import 'profile_tabs.dart';
import 'push_navigation.dart';
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
  final _pushSubscriptions = <StreamSubscription<PushMessage>>[];

  void _go(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPush());
  }

  @override
  void dispose() {
    for (final s in _pushSubscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  /// Push notifications (docs/features/push-notifications.md): listen for pushes, register this phone
  /// when allowed, open the job a launching push was about, and offer the one-time explanation.
  Future<void> _startPush() async {
    if (!mounted) return;
    final gateway = ref.read(pushGatewayProvider);
    final service = ref.read(pushServiceProvider);
    _pushSubscriptions
      ..add(gateway.foreground.listen(_showForeground))
      ..add(gateway.opened.listen(_openFromPush));
    await service.registerIfAllowed();
    final launch = await gateway.launchMessage();
    if (launch != null) unawaited(_openFromPush(launch));
    if (mounted && await service.shouldPrompt() && mounted) showPushPrompt(context, service);
  }

  /// Android shows nothing itself while the app is open, so the push appears as a toast.
  void _showForeground(PushMessage m) {
    if (mounted) KdToast.show(context, '${m.title}. ${m.body}');
  }

  Future<void> _openFromPush(PushMessage m) async {
    final jobId = m.jobId;
    if (jobId == null) return;
    // Refresh first: the push is about something that just changed, and the list may be older than that.
    await ref.read(jobsProvider.notifier).refresh();
    if (!mounted) return;
    final jobs = ref.read(jobsProvider).valueOrNull ?? const [];
    final job = jobs.where((j) => j.id == jobId).firstOrNull;
    final screen = screenForPush(role: ref.read(authProvider).user?.role, job: job);
    if (screen != null) unawaited(Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isClient = user?.role == 'client';
    final jobs = ref.watch(jobsProvider).valueOrNull ?? const [];
    final unread = ref.watch(unreadMessagesProvider);

    final List<Widget> screens;
    final List<KdTab> tabs;
    if (isClient) {
      final needs = ClientJobsTab.mine(jobs, user?.id).where((j) => contractNeedsYou(j, forClient: true)).length;
      screens = [ClientJobsTab(onPostJob: () => _go(2)), const BrowseTalentsScreen(), PostJobFlow(onPosted: () => _go(0)), const MessagesScreen(), const ClientProfileTab()];
      tabs = [
        KdTab(icon: Icons.work_outline_rounded, activeIcon: Icons.work_rounded, label: 'My jobs', badge: needs),
        const KdTab(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Talents'),
        const KdTab(icon: Icons.add_circle_outline_rounded, activeIcon: Icons.add_circle_rounded, label: 'Post'),
        KdTab(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Messages', badge: unread),
        const KdTab(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
      ];
    } else {
      final needs = WorkTab.mine(jobs).where((j) => contractNeedsYou(j, forClient: false)).length;
      screens = [const JobFeedScreen(), WorkTab(onBrowseJobs: () => _go(0)), const MessagesScreen(), const TalentProfileTab()];
      tabs = [
        const KdTab(icon: Icons.search_rounded, activeIcon: Icons.search_rounded, label: 'Jobs'),
        KdTab(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Work', badge: needs),
        KdTab(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Messages', badge: unread),
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
