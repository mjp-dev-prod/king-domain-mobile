import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../../data/models/job.dart';
import '../../providers/discovery_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_image.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import '../messages/conversation_screen.dart';
import '../../providers/messaging_provider.dart';
import 'invite_sheet.dart';

/// A talent as a client sees them (PRD §5): the facts, then the verified work itself. No score, no rank.
class TalentProfileScreen extends ConsumerWidget {
  final String talentId;

  /// Set when the client came from one of their jobs, so they can invite this person to it.
  final Job? forJob;
  const TalentProfileScreen({super.key, required this.talentId, this.forJob});

  Future<void> _toggleSave(BuildContext context, WidgetRef ref, TalentCard t) async {
    try {
      await ref.read(discoveryActionsProvider).setSaved(t.id, saved: !t.saved);
      if (context.mounted) KdToast.show(context, t.saved ? 'Removed from saved talents' : 'Saved. Find them in Saved talents.');
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    try {
      final id = await startConversation(ref, talentId);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversationId: id)));
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(talentProfileViewProvider(talentId));
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load this profile. Check your connection and try again.", onRetry: () async => ref.invalidate(talentProfileViewProvider(talentId)))),
        data: (p) {
          final t = p.card;
          return ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
            children: [
              ContractHeader(title: t.fullName, sub: t.headline ?? t.lastActiveText, pill: t.newOnKingDomain ? StatusPill('New on ${AppBrand.name}', tone: KdTone.brand) : StatusPill(t.lastActiveText)),
              const SizedBox(height: 16),
              RiseIn(
                child: KdCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [UserAvatar(name: t.fullName, photoUrl: t.photoUrl, size: 56), const SizedBox(width: 14), Expanded(child: Text(p.bio ?? 'No bio yet.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)))]),
                    const SizedBox(height: 14),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final s in t.verifiedSkills) StatusPill('Verified: ${s.label}', tone: KdTone.ok, icon: Icons.verified_outlined),
                      if (t.identityVerified) const StatusPill('Identity checked', tone: KdTone.ok),
                      StatusPill(t.completedJobs == 0 ? 'No completed jobs yet' : '${t.completedJobs} job${t.completedJobs == 1 ? '' : 's'} done'),
                      if (t.educationText != null && t.educationText!.isNotEmpty) StatusPill(t.educationText!),
                      if (t.regionText != null && t.regionText!.isNotEmpty) StatusPill(t.regionText!),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              if (forJob != null) KdButton(label: 'Invite to "${forJob!.title}"', icon: Icons.mail_outline_rounded, onPressed: () => showInviteSheet(context, ref, job: forJob!, talent: t)),
              if (forJob != null) const SizedBox(height: 8),
              KdButton.secondary(label: 'Message ${t.fullName.split(' ').first}', icon: Icons.chat_bubble_outline_rounded, onPressed: () => _message(context, ref)),
              const SizedBox(height: 8),
              KdButton.secondary(label: t.saved ? 'Saved. Tap to remove' : 'Save this talent', icon: t.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, onPressed: () => _toggleSave(context, ref, t)),
              const SizedBox(height: 20),
              Text('Verified work', style: AppTextStyles.title),
              const SizedBox(height: 4),
              Text('Each skill was checked by a person and scored by two reviewers.', style: AppTextStyles.hint),
              const SizedBox(height: 10),
              if (p.work.isEmpty) const EmptyState(icon: Icons.inventory_2_outlined, title: 'No verified work to show yet', body: 'Older proof is not shown here. Verified skills appear with their pieces.'),
              for (final w in p.work) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${w.skillLabel}${w.verifiedAt == null ? '' : ' · verified ${formatAgo(w.verifiedAt!)}'}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                ),
                for (final piece in w.pieces) Padding(padding: const EdgeInsets.only(bottom: 10), child: _Piece(piece: piece)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Piece extends StatelessWidget {
  final WorkPiece piece;
  const _Piece({required this.piece});

  @override
  Widget build(BuildContext context) {
    final images = piece.files.where((f) => f.contentType.startsWith('image/') && f.url != null).toList();
    final others = piece.files.where((f) => !(f.contentType.startsWith('image/') && f.url != null)).toList();
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              for (var i = 0; i < images.length.clamp(0, 3); i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: AspectRatio(aspectRatio: 4 / 3, child: WorkImage(url: images[i].url, radius: AppDimensions.radiusSm))),
              ],
            ]),
          ),
        Text(piece.title.isEmpty ? 'Untitled' : piece.title, style: AppTextStyles.title),
        if (piece.role.isNotEmpty || piece.madeOn.isNotEmpty) Text([piece.role, piece.madeOn].where((x) => x.isNotEmpty).join(' · '), style: AppTextStyles.hint),
        if (piece.brief.isNotEmpty) ...[const SizedBox(height: 6), Text(piece.brief, style: AppTextStyles.bodyMedium)],
        if (others.isNotEmpty || (piece.liveLink ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text([for (final f in others) f.name, if ((piece.liveLink ?? '').isNotEmpty) 'Live link: ${piece.liveLink}'].join(' · '), style: AppTextStyles.hint),
        ],
      ]),
    );
  }
}
