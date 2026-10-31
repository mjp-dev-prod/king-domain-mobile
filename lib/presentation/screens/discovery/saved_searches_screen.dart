import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../providers/discovery_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';

/// Saved job searches and their alerts (PRD §3.1 step 7): free for everyone, off with one switch.
class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, SavedSearch s, bool on) async {
    try {
      await ref.read(discoveryActionsProvider).setSearchAlerts(s.id, on);
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedSearch s) async {
    final actions = ref.read(discoveryActionsProvider);
    try {
      await actions.deleteSearch(s.id);
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      return;
    }
    if (!context.mounted) return;
    // Reversible, so it says so: Undo saves it again as it was.
    KdToast.show(context, 'Deleted "${s.name}"', actionLabel: 'Undo', onAction: () => actions.restoreSearch(s));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedSearchesProvider);
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load your saved searches. Check your connection and try again.", onRetry: () async => ref.invalidate(savedSearchesProvider))),
        data: (list) => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
          children: [
            ContractHeader(
              title: 'Saved searches',
              sub: 'We tell you the moment a new job matches one. Alerts are free.',
              pill: StatusPill(list.isEmpty ? 'None yet' : '${list.length} saved', tone: list.isEmpty ? KdTone.plain : KdTone.brand),
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'Nothing saved yet',
                body: 'On the Jobs tab, pick your filters and tap the bookmark. We will alert you whenever a matching job goes live.',
                actionLabel: 'Back to jobs',
                onAction: () => Navigator.of(context).pop(),
              ),
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RiseIn(
                  delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                  child: KdCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(list[i].name, style: AppTextStyles.title),
                              const SizedBox(height: 2),
                              Text(list[i].summary, style: AppTextStyles.hint),
                            ],
                          ),
                        ),
                        Semantics(label: 'Alerts for ${list[i].name}', child: Switch(value: list[i].alerts, onChanged: (v) => _toggle(context, ref, list[i], v), activeTrackColor: AppColors.primary)),
                        Pressable(
                          onTap: () => _delete(context, ref, list[i]),
                          semanticLabel: 'Delete ${list[i].name}',
                          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.delete_outline_rounded, color: AppColors.text3)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
