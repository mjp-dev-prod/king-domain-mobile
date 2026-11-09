import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/skill_submission.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import '../payments/payout_account_screen.dart';
import '../identity/identity_rows.dart';
import '../skills/sent_work_screen.dart';
import '../skills/skills_hub_screen.dart';
import '../skills/skills_row.dart';
import '../profile/profile_builder_screen.dart';
import '../profile/my_reputation_screen.dart';
import '../packages/my_packages_screen.dart';
import '../packages/package_browse_screen.dart';
import '../packages/package_orders_screen.dart';
import '../profile/settings_screen.dart';
import '../profile/profile_photo_button.dart';

/// Sign out asks first (it's easy to tap by accident, and it ends every
/// in-progress screen). Signing out clears the login, and every pushed screen is then closed so the person is back on Welcome.
void confirmSignOut(BuildContext context, WidgetRef ref) {
  showKdSheet(
    context,
    builder: (sheet) => KdSheetBody(
      title: 'Sign out?',
      lead: 'You\'ll need your email and password to sign back in.',
      children: [
        const SizedBox(height: 18),
        KdButton(
          label: 'Sign out',
          variant: KdButtonVariant.danger,
          busyLabel: 'Signing out',
          onPressed: () async {
            final nav = Navigator.of(sheet, rootNavigator: true);
            nav.pop();
            await ref.read(authProvider.notifier).logout();
            // Signing out only swaps what is underneath. A screen pushed on top (Settings, where this button now lives)
            // would stay up until Back; close them all so the person lands on Welcome.
            nav.popUntil((route) => route.isFirst);
          },
        ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Stay signed in', onPressed: () => Navigator.of(sheet).pop()),
      ],
    ),
  );
}

/// The foot of both profile tabs: what is about your work (packages, reputation), then one way into Settings, where
/// notifications, display, data, privacy and the account itself live.
class _AccountGroup extends ConsumerWidget {
  const _AccountGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListGroup(
      rows: [
        if (ref.watch(authProvider).user?.role == 'client') ...[
          ListRow(icon: Icons.inventory_2_outlined, title: 'Packages', sub: 'Ready-made offers from verified talents', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackageBrowseScreen()))),
          ListRow(icon: Icons.inbox_outlined, title: 'Your package orders', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackageOrdersScreen()))),
        ] else ...[
          ListRow(icon: Icons.inventory_2_outlined, title: 'Your packages', sub: 'Publish ready-made offers and answer orders', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyPackagesScreen()))),
        ],
        ListRow(
          icon: Icons.workspace_premium_outlined,
          title: 'Your reputation',
          sub: 'What others see, Proven levels and credentials',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyReputationScreen())),
        ),
        ListRow(
          icon: Icons.settings_outlined,
          title: 'Settings',
          sub: 'Notifications, money, data, privacy, your account',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }
}

void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

/// The one thing to do next, in the order that unlocks the most: finish the profile, get verified in a skill (what lets
/// you apply), add a payout account. Nothing once all three are done. Replaces the old three-step stepper.
List<Widget> _nextStep(BuildContext context, TalentProfile p, bool hasVerifiedSkill) {
  final (IconData, String, String, Widget)? next = !p.isProfileComplete
      ? (Icons.badge_outlined, 'Finish your profile', 'Add a headline and a bio, and say what work you do.', const ProfileBuilderScreen())
      : !hasVerifiedSkill
          ? (Icons.verified_outlined, 'Get verified in a skill', 'Send two or three pieces of real work. It is what lets you apply to jobs.', const SkillsHubScreen())
          : p.payoutAccount == null
              ? (Icons.account_balance_outlined, 'Add a payout account', 'It is where you are paid when a client approves your work.', const PayoutAccountScreen())
              : null;
  if (next == null) return const [];
  return [
    const SizedBox(height: 18),
    KdCard(
      tone: KdTone.brand,
      onTap: () => _open(context, next.$4),
      child: Row(
        children: [
          Icon(next.$1, color: AppColors.primaryText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(next.$2, style: AppTextStyles.title),
                const SizedBox(height: 2),
                Text(next.$3, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primaryText),
        ],
      ),
    ),
  ];
}

/// Talent's profile tab (prototypes/palette-explorer.html, screen 04). Only
/// real data: no "jobs done" or "earned" figures until the backend has them.
class TalentProfileTab extends ConsumerWidget {
  const TalentProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(talentProfileProvider);
    final name = ref.watch(authProvider).user?.fullName ?? '';

    if (profileAsync.isLoading && !profileAsync.hasValue) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 40, AppDimensions.gutter, 120),
        children: const [Center(child: Skeleton(height: 92, width: 92, radius: 46)), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
      );
    }
    if (profileAsync.hasError && !profileAsync.hasValue) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 40, AppDimensions.gutter, 120),
        children: [ErrorState(message: 'Couldn\'t load your profile.', onRetry: () async => ref.invalidate(talentProfileProvider))],
      );
    }
    final p = profileAsync.value!;
    // Verified means verified in a skill through a submission two reviewers passed. Nothing else earns a badge.
    final hub = ref.watch(skillHubProvider).valueOrNull;
    final verifiedSkills = [for (final s in hub?.skills ?? const <SkillHubEntry>[]) if (s.state == SkillState.verified && s.currentSubmissionId != null) s];
    final steps = [p.isProfileComplete, verifiedSkills.isNotEmpty, p.payoutAccount != null];
    final done = steps.where((s) => s).length;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(talentProfileProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 20, AppDimensions.gutter, 120),
        children: [
          Center(child: ProfilePhotoButton(size: 84, ring: done / steps.length)),
          const SizedBox(height: 12),
          Text(name.isEmpty ? 'Your profile' : name, textAlign: TextAlign.center, style: AppTextStyles.h2),
          if (p.headline.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(p.headline, textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(fontSize: 13.5)),
          ],
          if (verifiedSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                // Only skills earned through a passed submission. Tapping one shows what was verified.
                for (final s in verifiedSkills)
                  Pressable(
                    onTap: () => openSentWork(context, s.currentSubmissionId!),
                    semanticLabel: 'Verified in ${s.label}. See what was verified',
                    child: StatusPill('${s.label} verified', tone: KdTone.ok, icon: Icons.verified_outlined),
                  ),
              ],
            ),
          ],
          ..._nextStep(context, p, verifiedSkills.isNotEmpty),
          const SizedBox(height: 20),
          const SkillsRow(),
          const SizedBox(height: 12),
          const IdentityGroup(),
          const SizedBox(height: 12),
          ListGroup(
            rows: [
              ListRow(
                icon: Icons.account_balance_outlined,
                title: 'Payout account',
                sub: p.payoutAccount == null
                    ? 'Not set · add one so you can be paid'
                    : '${p.payoutAccount!.bankName ?? 'Bank'} ••${p.payoutAccount!.accountNumberLast4} · ${p.payoutAccount!.accountName}',
                subTone: p.payoutAccount == null ? KdTone.warn : KdTone.plain,
                onTap: () => _open(context, const PayoutAccountScreen()),
              ),
              ListRow(icon: Icons.badge_outlined, title: 'Profile', sub: 'Headline, bio, the work you do', onTap: () => _open(context, const ProfileBuilderScreen())),
            ],
          ),
          const SizedBox(height: 12),
          const _AccountGroup(),
        ],
      ),
    );
  }
}


/// Client's profile tab.
class ClientProfileTab extends ConsumerWidget {
  const ClientProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final name = user?.fullName ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 20, AppDimensions.gutter, 120),
      children: [
        Center(child: ProfilePhotoButton(size: 84)),
        const SizedBox(height: 12),
        Text(name.isEmpty ? 'Your profile' : name, textAlign: TextAlign.center, style: AppTextStyles.h2),
        Text(user?.email ?? '', textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(fontSize: 13.5)),
        const SizedBox(height: 24),
        const IdentityGroup(),
        const SizedBox(height: 12),
        const _AccountGroup(),
      ],
    );
  }
}
