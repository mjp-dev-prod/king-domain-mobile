import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../providers/discovery_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import 'browse_talents_screen.dart';
import 'talent_profile_screen.dart';

/// Talents a client saved, to hire again or invite later (PRD §3.2).
class SavedTalentsScreen extends ConsumerWidget {
  const SavedTalentsScreen({super.key});

  Future<void> _unsave(BuildContext context, WidgetRef ref, TalentCard t) async {
    final actions = ref.read(discoveryActionsProvider);
    try {
      await actions.setSaved(t.id, saved: false);
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      return;
    }
    if (context.mounted) KdToast.show(context, 'Removed ${t.fullName.split(' ').first}', actionLabel: 'Undo', onAction: () => actions.setSaved(t.id, saved: true));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedTalentsProvider);
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load your saved talents. Check your connection and try again.", onRetry: () async => ref.invalidate(savedTalentsProvider))),
        data: (list) => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
          children: [
            ContractHeader(title: 'Saved talents', sub: 'People you want to find again.', pill: StatusPill(list.isEmpty ? 'None yet' : '${list.length} saved', tone: list.isEmpty ? KdTone.plain : KdTone.brand)),
            const SizedBox(height: 16),
            if (list.isEmpty)
              EmptyState(icon: Icons.bookmark_border_rounded, title: 'Nobody saved yet', body: 'Tap the bookmark on any talent to keep them here.', actionLabel: 'Browse talents', onAction: () => Navigator.of(context).pop()),
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RiseIn(
                  delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                  child: TalentCardView(
                    talent: list[i],
                    onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TalentProfileScreen(talentId: list[i].id))),
                    onSave: () => _unsave(context, ref, list[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
