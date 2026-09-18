import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/talent_profile_provider.dart';
import '../proof/proof_upload_screen.dart';
import 'profile_builder_screen.dart';

/// Complete-your-profile overview — a vertical step tracker (each step a
/// row: icon, label, status pill, "Continue"/"View details" link), styled
/// after C:\work\rentipede's ApplicationOverviewPage pattern rather than
/// the old forced VerifyEmail -> ProfileBuilder -> ProofUpload chain.
/// Reachable any time from the Profile tab — completing a profile is no
/// longer a gate before entering the app; applying to jobs still requires
/// verified proof, enforced server-side (jobsRoutes.js), unaffected here.
class ProfileOverviewScreen extends ConsumerWidget {
  const ProfileOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(talentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Could not load your profile.', style: AppTextStyles.bodyMedium),
          ),
          data: (profile) {
            final profileDone = profile.isProfileComplete;
            final hasAnyProof = profile.proofItems.isNotEmpty;
            final verifiedCount =
                profile.proofItems.where((p) => p.status == ProofReviewStatus.verified).length;
            final pendingCount = profile.proofItems.length - verifiedCount;

            final doneCount = (profileDone ? 1 : 0) + (hasAnyProof ? 1 : 0);

            return ListView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              children: [
                Text(
                  '$doneCount / 2 steps completed',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateDim),
                ),
                const SizedBox(height: AppDimensions.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: LinearProgressIndicator(
                    value: doneCount / 2,
                    minHeight: 6,
                    backgroundColor: AppColors.ink3,
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),
                _StepRow(
                  icon: Icons.badge_outlined,
                  title: 'Profile',
                  subtitle: 'Headline, bio, and skill categories.',
                  done: profileDone,
                  actionLabel: profileDone ? 'View details' : 'Continue',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileBuilderScreen()),
                  ),
                ),
                const _StepConnector(),
                _StepRow(
                  icon: Icons.verified_outlined,
                  title: 'Proof of work',
                  subtitle: hasAnyProof
                      ? '$verifiedCount verified'
                          '${pendingCount > 0 ? ' · $pendingCount pending review' : ''}'
                      : 'Submit at least one work sample per category.',
                  done: hasAnyProof,
                  locked: !profileDone,
                  actionLabel: hasAnyProof ? 'View details' : 'Continue',
                  onTap: profileDone
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProofUploadScreen()),
                          )
                      : null,
                ),
                const SizedBox(height: AppDimensions.xl),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Text(
                    'You can browse the app freely, but applying to a job requires '
                    'Verified proof in that job\'s category.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateDim),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 19),
      child: Container(width: 1.5, height: 20, color: AppColors.ink3),
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool locked;
  final String actionLabel;
  final VoidCallback? onTap;

  const _StepRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    this.locked = false,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final circleColor = done
        ? AppColors.settled
        : locked
            ? AppColors.ink3
            : AppColors.gold;
    final iconColor = locked ? AppColors.slateDim : AppColors.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
              child: Icon(
                locked ? Icons.lock_outline : (done ? Icons.check : icon),
                size: AppDimensions.iconSm,
                color: locked ? AppColors.slateDim : iconColor,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      _StatusPill(done: done, locked: locked),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                  if (!locked) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      actionLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool done;
  final bool locked;

  const _StatusPill({required this.done, required this.locked});

  @override
  Widget build(BuildContext context) {
    final (label, color) = locked
        ? ('Locked', AppColors.slateDim)
        : done
            ? ('Completed', AppColors.settled)
            : ('Action required', AppColors.openPending);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: color, fontSize: 10)),
    );
  }
}
