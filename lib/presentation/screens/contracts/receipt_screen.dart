import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/contract_extras.dart';
import '../../providers/contract_extras_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/about_amount_text.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';

/// The record of a payment: who paid whom, how much, when, for what. It is what a bank or Paystack asks for if a
/// payment is ever questioned, so it is kept plain and complete. Clients see what they paid; talents also see
/// what was paid to them.
class ReceiptScreen extends ConsumerWidget {
  final String jobId;
  const ReceiptScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptProvider(jobId));
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (e, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(
              child: Center(
                child: e is ApiException && e.code == 'not_paid'
                    ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No receipt yet', body: 'A receipt appears here once the job has been paid for.')
                    : ErrorState(message: 'Couldn\'t load the receipt. Check your connection and try again.', onRetry: () async => ref.invalidate(receiptProvider(jobId))),
              ),
            ),
          ]),
        ),
        data: (r) => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
          children: [
            ContractHeader(title: 'Receipt', sub: r.jobTitle, pill: StatusPill(r.status == 'approved' ? 'Paid out' : 'Held safely', tone: r.status == 'approved' ? KdTone.ok : KdTone.brand)),
            const SizedBox(height: 12),
            RiseIn(child: _Section(title: 'What was paid for', rows: [('Service', r.service), ('Client', r.clientName), if (r.talentName != null) ('Talent', r.talentName!)])),
            const SizedBox(height: 12),
            RiseIn(
              delay: const Duration(milliseconds: 60),
              child: _Section(title: 'Payment', rows: [
                ('Price', formatMoney(r.price, r.currency)),
                ('Service fee', formatMoney(r.platformFee, r.currency)),
                ('Total paid by the client', formatMoney(r.totalPaidByClient, r.currency)),
                if (r.paidAt != null) ('Paid on', formatDeadline(r.paidAt!)),
                if (r.reference != null) ('Reference', r.reference!),
              ], footer: AboutAmountText(amount: r.totalPaidByClient, currency: r.currency)),
            ),
            if (r.hasPayouts) ...[
              const SizedBox(height: 12),
              RiseIn(
                delay: const Duration(milliseconds: 120),
                child: _Section(title: 'Paid to the talent', rows: [
                  ('First 20% (start proof)', _payout(r.upfront, r.currency, 'Not paid yet')),
                  ('The rest (on approval)', _payout(r.finalPayout, r.currency, 'Not paid yet')),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _payout(Payout? p, String currency, String none) => p == null ? none : '${formatMoney(p.amount, currency)}${p.paidAt == null ? '' : ' · ${formatDeadline(p.paidAt!)}'}';
}

class _Section extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  final Widget? footer;
  const _Section({required this.title, required this.rows, this.footer});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          for (final (label, value) in rows) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2))),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: Text(value, textAlign: TextAlign.right, style: AppTextStyles.bodyMedium)),
              ],
            ),
          ],
          if (footer != null) Align(alignment: Alignment.centerRight, child: footer),
        ],
      ),
    );
  }
}
