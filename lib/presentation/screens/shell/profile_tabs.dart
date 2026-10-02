import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/talent_profile.dart';
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
import '../profile/profile_overview_screen.dart';

/// Sign out asks first (it's easy to tap by accident, and it ends every
/// in-progress screen). RootRouter takes the user back to Welcome.
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
            Navigator.of(sheet).pop();
            await ref.read(authProvider.notifier).logout();
          },
        ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Stay signed in', onPressed: () => Navigator.of(sheet).pop()),
      ],
    ),
  );
}

void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

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
    final verified = p.skillCategories.where(p.isVerifiedIn).toList();
    final steps = [p.isProfileComplete, p.proofItems.isNotEmpty, p.payoutAccount != null];
    final done = steps.where((s) => s).length;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(talentProfileProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 20, AppDimensions.gutter, 120),
        children: [
          Center(child: InitialsAvatar(name: name, size: 84, ring: done / steps.length)),
          const SizedBox(height: 12),
          Text(name.isEmpty ? 'Your profile' : name, textAlign: TextAlign.center, style: AppTextStyles.h2),
          if (p.headline.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(p.headline, textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(fontSize: 13.5)),
          ],
          if (p.skillCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in p.skillCategories)
                  p.isVerifiedIn(c) ? StatusPill('$c verified', tone: KdTone.ok, icon: Icons.verified_outlined) : StatusPill(c),
              ],
            ),
          ],
          if (done < steps.length) ...[
            const SizedBox(height: 18),
            KdCard(
              tone: KdTone.brand,
              onTap: () => _open(context, const ProfileOverviewScreen()),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, color: AppColors.primaryText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Finish your profile · $done of ${steps.length}', style: AppTextStyles.title),
                        const SizedBox(height: 2),
                        Text(
                          verified.isEmpty
                              ? 'Verified proof of work is what lets you apply to jobs.'
                              : 'Add proof in more categories to open more jobs.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.primaryText),
                ],
              ),
            ),
          ],
          SectionHeader('Proof of work', action: 'Manage', onAction: () => _open(context, const ProfileOverviewScreen())),
          if (p.proofItems.isEmpty)
            KdCard(
              onTap: () => _open(context, const ProfileOverviewScreen()),
              child: Text(
                'No proof yet. Add a real piece of work for each skill; a ${AppBrand.name} reviewer checks it before you can apply in that category.',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
              ),
            )
          else ...[
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              childAspectRatio: .62,
              children: [for (final item in p.proofItems) _ProofThumb(item: item)],
            ),
            const SizedBox(height: 8),
            Text('Verified means a ${AppBrand.name} reviewer checked the work is yours. The picture alone isn\'t the proof.', style: AppTextStyles.hint),
          ],
          const SizedBox(height: 20),
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
              ListRow(icon: Icons.badge_outlined, title: 'Profile and skills', sub: 'Headline, bio, categories', onTap: () => _open(context, const ProfileOverviewScreen())),
            ],
          ),
          const SizedBox(height: 12),
          ListGroup(rows: [ListRow(icon: Icons.logout_rounded, title: 'Sign out', danger: true, onTap: () => confirmSignOut(context, ref))]),
        ],
      ),
    );
  }
}

class _ProofThumb extends StatelessWidget {
  final ProofItem item;
  const _ProofThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final verified = item.status == ProofReviewStatus.verified;
    final fallback = Container(
      color: AppColors.surface2,
      alignment: Alignment.center,
      child: const Icon(Icons.description_outlined, color: AppColors.text3),
    );
    return Pressable(
      onTap: () => _open(context, const ProfileOverviewScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: item.fileUrl == null
                  ? fallback
                  : Image.network(
                      item.fileUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      // Fade in over a surface colour; a non-image file (PDF) shows the file icon.
                      frameBuilder: (_, child, frame, sync) => sync
                          ? child
                          : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 400), child: child),
                      loadingBuilder: (_, child, progress) => progress == null ? child : Container(color: AppColors.surface2),
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          verified
              ? const StatusPill('Verified', tone: KdTone.ok, icon: Icons.check_rounded)
              : const StatusPill('In review', tone: KdTone.warn),
          const SizedBox(height: 4),
          Flexible(
            child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(fontSize: 11.5, height: 1.3)),
          ),
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
        Center(child: InitialsAvatar(name: name, size: 84)),
        const SizedBox(height: 12),
        Text(name.isEmpty ? 'Your profile' : name, textAlign: TextAlign.center, style: AppTextStyles.h2),
        Text(user?.email ?? '', textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(fontSize: 13.5)),
        const SizedBox(height: 24),
        ListGroup(rows: [ListRow(icon: Icons.logout_rounded, title: 'Sign out', danger: true, onTap: () => confirmSignOut(context, ref))]),
      ],
    );
  }
}
