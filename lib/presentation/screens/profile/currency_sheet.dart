import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../providers/contract_extras_provider.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';

/// Which currency the person thinks in. Money is always paid in the job's own currency; this only decides which
/// amounts get an "about" line beside them (D37).
void showCurrencySheet(BuildContext context) {
  showKdSheet(context, builder: (_) => const _CurrencyBody());
}

class _CurrencyBody extends ConsumerWidget {
  const _CurrencyBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(displayCurrencyProvider).valueOrNull ?? 'NGN';
    final rate = ref.watch(fxRateProvider).valueOrNull;

    Future<void> choose(String c) async {
      try {
        await ref.read(displayCurrencyProvider.notifier).choose(c);
      } on ApiException catch (e) {
        if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      }
    }

    return KdSheetBody(
      title: 'Money shown in',
      lead: 'Jobs are paid in the currency they were priced in. Pick the one you think in and we will add an "about" amount beside the other.',
      children: [
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          KdChoiceChip(label: 'Naira', selected: current == 'NGN', onTap: () => choose('NGN')),
          KdChoiceChip(label: 'Dollars', selected: current == 'USD', onTap: () => choose('USD')),
        ]),
        const SizedBox(height: 12),
        Text(
          rate?.ngnPerUsd == null
              ? 'No rate is set yet, so we show only the exact amount for now.'
              : '\$1 is about ₦${rate!.ngnPerUsd!.round()}${rate.asOf == null ? '' : ', set ${formatDeadline(rate.asOf!)}'}. Estimates only: what is paid is the exact amount.',
          style: AppTextStyles.hint,
        ),
        const SizedBox(height: 18),
        KdButton.secondary(label: 'Done', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
