import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/packages.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/packages_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import '../shell/push_navigation.dart';

/// Package orders, from the signed-in person's side. A talent has 48 hours to accept or decline each one; a client can
/// cancel while it waits. An accepted order is an ordinary job: the client pays within 24 hours, and the usual steps follow.
class PackageOrdersScreen extends ConsumerWidget {
  const PackageOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(packageOrdersProvider);
    final isClient = ref.watch(authProvider).user?.role == 'client';
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: ErrorState(message: 'Couldn\'t load the orders. Check your connection and try again.', onRetry: () async => ref.invalidate(packageOrdersProvider)))),
          ]),
        ),
        data: (orders) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(packageOrdersProvider),
          child: LiveClock(
            builder: (_) => ListView(
              padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
              children: [
                ContractHeader(title: 'Package orders', sub: isClient ? 'What you have ordered' : 'What clients have ordered from you', pill: StatusPill('${orders.where((o) => o.waiting).length} waiting', tone: KdTone.warn)),
                const SizedBox(height: 12),
                if (orders.isEmpty)
                  EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No orders yet',
                    body: isClient ? 'When you order a package it shows up here while the talent decides.' : 'When a client orders one of your packages it shows up here, and you have 48 hours to answer.',
                  ),
                for (var i = 0; i < orders.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: RiseIn(delay: Duration(milliseconds: 40 * i.clamp(0, 6)), child: _OrderCard(o: orders[i], isClient: isClient))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final PackageOrderItem o;
  final bool isClient;
  const _OrderCard({required this.o, required this.isClient});

  Future<void> _answer(BuildContext context, WidgetRef ref, bool accept) async {
    try {
      await ref.read(packageActionsProvider).answerOrder(o.id, accept: accept);
      await ref.read(jobsProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (context.mounted) KdToast.show(context, accept ? 'Accepted. They have 24 hours to pay' : 'Declined');
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final id = o.jobId;
    if (id == null) return;
    try {
      final job = await ref.read(jobsProvider.notifier).fetchOne(id);
      final screen = screenForPush(role: ref.read(authProvider).user?.role, job: job);
      if (screen != null && context.mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = o.waiting ? timeLeft(o.answerDueAt) : null;
    final (tone, label) = switch (o.status) {
      'requested' => (KdTone.warn, left == null ? 'Lapsing now' : 'Waiting · $left left'),
      'accepted' => (KdTone.ok, 'Accepted'),
      'declined' => (KdTone.plain, 'Declined'),
      'expired' => (KdTone.plain, 'No answer in 48 hours'),
      _ => (KdTone.plain, 'Cancelled'),
    };
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(o.title, style: AppTextStyles.title)),
          StatusPill(label, tone: tone),
        ]),
        const SizedBox(height: 4),
        Text('${isClient ? 'From' : 'For'} ${o.other}${o.skillLabel == null ? '' : ' · ${o.skillLabel}'}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2)),
        const SizedBox(height: 4),
        Text('${formatMoney(o.price, o.currency)}${o.deliveryDays == null ? '' : ' · ${o.deliveryDays} days'}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.money)),
        if (o.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('"${o.note}"', style: AppTextStyles.bodySmall)),
        const SizedBox(height: 10),
        if (o.waiting && !isClient)
          Row(children: [
            Expanded(child: KdButton.secondary(label: 'Decline', height: AppDimensions.buttonHeightSm, busyLabel: 'Declining', onPressed: () => _answer(context, ref, false))),
            const SizedBox(width: 10),
            Expanded(child: KdButton(label: 'Accept', height: AppDimensions.buttonHeightSm, busyLabel: 'Accepting', onPressed: () => _answer(context, ref, true))),
          ])
        else if (o.waiting && isClient)
          KdButton.secondary(
            label: 'Cancel this order',
            height: AppDimensions.buttonHeightSm,
            busyLabel: 'Cancelling',
            onPressed: () async {
              try {
                await ref.read(packageActionsProvider).cancelOrder(o.id);
              } on ApiException catch (e) {
                if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (context.mounted) KdToast.show(context, 'Cancelled. Nothing was charged');
            },
          )
        else if (o.status == 'accepted')
          KdButton(label: isClient ? 'Pay and start' : 'Open the job', height: AppDimensions.buttonHeightSm, onPressed: () => _open(context, ref))
        else if (o.status == 'expired' || o.status == 'declined')
          Text(isClient ? 'Nothing was charged. You can order another package or post the job.' : 'Nothing is owed on this one.', style: AppTextStyles.hint),
      ]),
    );
  }
}
