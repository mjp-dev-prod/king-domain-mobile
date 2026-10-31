import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../providers/discovery_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';

/// "A client may want you" (D24): the team asks before anything is shown to the client. Only talents who
/// answer yes are ever put on a shortlist.
class ShortlistAsksScreen extends ConsumerWidget {
  const ShortlistAsksScreen({super.key});

  Future<void> _answer(BuildContext context, WidgetRef ref, ShortlistAsk a, bool yes) async {
    try {
      await ref.read(discoveryActionsProvider).answerAsk(a.id, available: yes);
      if (context.mounted) KdToast.show(context, yes ? "Thanks. We'll show you to the client." : "No problem. You won't be shown.");
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shortlistAsksProvider);
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load this. Check your connection and try again.", onRetry: () async => ref.invalidate(shortlistAsksProvider))),
        data: (asks) {
          final waiting = asks.where((a) => a.available == null).length;
          return ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
            children: [
              ContractHeader(
                title: 'Are you free?',
                sub: 'King Domain is picking people for a client. Nobody sees you unless you say yes.',
                pill: StatusPill(waiting == 0 ? 'Nothing waiting' : '$waiting waiting', tone: waiting == 0 ? KdTone.plain : KdTone.brand),
              ),
              const SizedBox(height: 16),
              if (asks.isEmpty)
                const EmptyState(icon: Icons.person_search_outlined, title: 'Nobody is asking right now', body: 'When the team is building a shortlist and your work fits, you are asked here first.'),
              for (var i = 0; i < asks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RiseIn(
                    delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                    child: KdCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Expanded(child: Text('${asks[i].skillLabel} job', style: AppTextStyles.title)), Text(formatAgo(asks[i].askedAt), style: AppTextStyles.hint)]),
                          const SizedBox(height: 4),
                          Text('Budget ${asks[i].budgetText}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.money)),
                          const SizedBox(height: 12),
                          if (asks[i].available == null)
                            Row(children: [
                              Expanded(child: KdButton(label: "Yes, I'm free", height: AppDimensions.buttonHeightSm, onPressed: () => _answer(context, ref, asks[i], true))),
                              const SizedBox(width: 8),
                              Expanded(child: KdButton.secondary(label: 'Not now', height: AppDimensions.buttonHeightSm, onPressed: () => _answer(context, ref, asks[i], false))),
                            ])
                          else
                            StatusPill(asks[i].available! ? 'You said yes' : 'You said no', tone: asks[i].available! ? KdTone.ok : KdTone.plain),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
