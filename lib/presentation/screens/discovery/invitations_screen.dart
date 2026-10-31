import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../../data/models/job.dart';
import '../../providers/discovery_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import '../jobs/job_detail_screen.dart';
import '../skills/skills_hub_screen.dart';

/// Jobs a client invited this talent to (PRD §3.1 step 7; D23): each valid for 72 hours.
class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  Future<void> _decline(BuildContext context, WidgetRef ref, InvitationItem i) async {
    try {
      await ref.read(discoveryActionsProvider).respondInvitation(i.id, accept: false);
      if (context.mounted) KdToast.show(context, 'Declined');
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invitationsProvider);
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load your invitations. Check your connection and try again.", onRetry: () async => ref.invalidate(invitationsProvider))),
        data: (items) {
          final open = items.where((i) => i.open).length;
          return ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
            children: [
              ContractHeader(
                title: 'Invitations',
                sub: 'Clients who want you for a job. Each one is open for 72 hours.',
                pill: StatusPill(open == 0 ? 'None open' : '$open open', tone: open == 0 ? KdTone.plain : KdTone.brand),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                EmptyState(
                  icon: Icons.mail_outline_rounded,
                  title: 'No invitations yet',
                  body: 'Clients invite talents they find by browsing. Verified skills and a complete profile are what they look at.',
                  actionLabel: 'Your skills',
                  onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkillsHubScreen())),
                ),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RiseIn(
                    delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                    child: _InvitationCard(item: items[i], onDecline: () => _decline(context, ref, items[i])),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final InvitationItem item;
  final VoidCallback onDecline;
  const _InvitationCard({required this.item, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final left = item.open ? timeLeft(item.expiresAt) : null;
    final pill = switch (item.status) {
      'accepted' => const StatusPill('You applied', tone: KdTone.ok, icon: Icons.check_rounded),
      'declined' => const StatusPill('Declined'),
      'expired' => const StatusPill('Expired'),
      _ => left == null ? const StatusPill('Expired') : StatusPill('$left left', tone: KdTone.warn),
    };
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(item.from, style: AppTextStyles.bodySmall)), pill]),
          const SizedBox(height: 6),
          Text(item.job.title, style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text('${item.job.skillOrCategory} · ${formatMoney(item.job.budget, item.job.currency)}${item.job.jobType.priceNote}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.money)),
          if (item.message != null && item.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('“${item.message}”', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: KdButton(label: item.open ? 'See the job' : 'View', height: AppDimensions.buttonHeightSm, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: item.job.id))))),
              if (item.open) ...[const SizedBox(width: 8), Expanded(child: KdButton.secondary(label: 'Decline', height: AppDimensions.buttonHeightSm, onPressed: onDecline))],
            ],
          ),
        ],
      ),
    );
  }
}
