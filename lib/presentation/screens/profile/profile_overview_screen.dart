import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import '../payments/payout_account_screen.dart';
import '../proof/proof_upload_screen.dart';
import 'profile_builder_screen.dart';

/// Complete-your-profile overview: three steps in a vertical tracker. Not a
/// gate before entering the app; applying to a job still requires verified
/// proof in its category, enforced server-side (jobsRoutes.js).
class ProfileOverviewScreen extends ConsumerWidget {
  const ProfileOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(talentProfileProvider);
    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: ErrorState(
            message: 'Couldn\'t load your profile. Check your connection and try again.',
            onRetry: () => ref.read(talentProfileProvider.notifier).refresh(),
          ),
        ),
        data: (profile) => _Overview(profile: profile),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final TalentProfile profile;
  const _Overview({required this.profile});

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final profileDone = profile.isProfileComplete;
    final verified = profile.proofItems.where((p) => p.status == ProofReviewStatus.verified).length;
    final pending = profile.proofItems.length - verified;
    final hasProof = profile.proofItems.isNotEmpty;
    final payout = profile.payoutAccount;
    final done = (profileDone ? 1 : 0) + (hasProof ? 1 : 0) + (payout != null ? 1 : 0);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final steps = [
      _Step(
        icon: Icons.badge_outlined,
        title: 'Profile',
        sub: profileDone ? profile.headline : 'Headline, bio, and the categories you work in.',
        state: profileDone ? _StepState.done : _StepState.todo,
        onTap: () => _open(context, const ProfileBuilderScreen()),
      ),
      _Step(
        icon: Icons.verified_outlined,
        title: 'Proof of work',
        sub: !profileDone
            ? 'Pick your categories first.'
            : hasProof
                ? '$verified verified${pending > 0 ? ' · $pending in review' : ''}'
                : 'One work sample per category, checked by a person.',
        state: !profileDone
            ? _StepState.locked
            : verified > 0
                ? _StepState.done
                : hasProof
                    ? _StepState.waiting
                    : _StepState.todo,
        onTap: profileDone ? () => _open(context, const ProofUploadScreen()) : null,
      ),
      _Step(
        icon: Icons.account_balance_outlined,
        title: 'Payout account',
        sub: payout != null ? '${payout.bankName ?? 'Bank'} · •••• ${payout.accountNumberLast4}' : 'Where your payments are sent when a client approves.',
        state: payout != null ? _StepState.done : _StepState.todo,
        onTap: () => _open(context, const PayoutAccountScreen()),
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
      children: [
        ContractHeader(
          title: 'Complete your profile',
          sub: 'Browse freely. To apply to a job you need verified proof in its category.',
          pill: StatusPill('$done of 3 done', tone: done == 3 ? KdTone.ok : KdTone.brand),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: done / 3),
            duration: reduce ? Duration.zero : AppMotion.arrive,
            curve: AppMotion.ease,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: AppColors.surface2, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        RiseIn(
          child: KdCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _StepRow(step: steps[i], first: i == 0, last: i == steps.length - 1, nextDone: i < steps.length - 1 && steps[i].state == _StepState.done),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _StepState { todo, waiting, done, locked }

class _Step {
  final IconData icon;
  final String title;
  final String sub;
  final _StepState state;
  final VoidCallback? onTap;
  const _Step({required this.icon, required this.title, required this.sub, required this.state, this.onTap});
}

/// One step: a circle on a thin vertical rail, the text, a pill and a
/// chevron. The rail segment below a finished step turns green.
class _StepRow extends StatelessWidget {
  final _Step step;
  final bool first;
  final bool last;
  final bool nextDone;
  const _StepRow({required this.step, required this.first, required this.last, required this.nextDone});

  @override
  Widget build(BuildContext context) {
    final (circle, ink, icon) = switch (step.state) {
      _StepState.done => (AppColors.okSoft, AppColors.ok, Icons.check_rounded),
      _StepState.waiting => (AppColors.warnSoft, AppColors.warn, step.icon),
      _StepState.todo => (AppColors.primarySoft, AppColors.primaryText, step.icon),
      _StepState.locked => (AppColors.surface2, AppColors.text3, Icons.lock_outline_rounded),
    };
    final pill = switch (step.state) {
      _StepState.done => const StatusPill('Done', tone: KdTone.ok),
      _StepState.waiting => const StatusPill('In review', tone: KdTone.warn),
      _StepState.todo => const StatusPill('To do', tone: KdTone.brand),
      _StepState.locked => const StatusPill('Locked'),
    };

    return Pressable(
      onTap: step.onTap,
      semanticLabel: step.title,
      scale: .985,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(width: 2, height: 12, color: first ? Colors.transparent : AppColors.surface3),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
                    child: Icon(icon, size: 20, color: ink),
                  ),
                  Expanded(child: Container(width: 2, color: last ? Colors.transparent : (nextDone ? AppColors.ok : AppColors.surface3))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(step.title, style: AppTextStyles.title)),
                        const SizedBox(width: 8),
                        pill,
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(step.sub, style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            if (step.onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.text3),
              ),
          ],
        ),
      ),
    );
  }
}
