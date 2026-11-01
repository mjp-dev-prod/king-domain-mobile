import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/about_amount.dart';
import '../../providers/contract_extras_provider.dart';

/// "about $13" under or beside an amount, only when the person shows money in the other currency and a rate is set.
/// Draws nothing while those load or if they fail: the exact amount is always shown by the caller.
class AboutAmountText extends ConsumerWidget {
  final num amount;
  final String currency;
  final TextStyle? style;
  const AboutAmountText({super.key, required this.amount, required this.currency, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayCurrencyProvider).valueOrNull;
    final rate = ref.watch(fxRateProvider).valueOrNull?.ngnPerUsd;
    if (display == null) return const SizedBox.shrink();
    final text = aboutAmount(amount, currency: currency, display: display, ngnPerUsd: rate);
    if (text == null) return const SizedBox.shrink();
    return Text(text, style: style ?? AppTextStyles.hint);
  }
}
