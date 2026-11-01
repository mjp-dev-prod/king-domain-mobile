import 'currency.dart';

/// The same amount in the person's display currency, worded as an estimate, or null when nothing should be shown:
/// the display currency is the job's own, or the team has not set a rate (D37). Money is always paid in the job's
/// own currency; this line only helps someone who thinks in the other one.
String? aboutAmount(num amount, {required String currency, required String display, required double? ngnPerUsd}) {
  if (currency == display || ngnPerUsd == null || ngnPerUsd <= 0) return null;
  final converted = currency == 'NGN' ? amount / ngnPerUsd : amount * ngnPerUsd;
  final rounded = display == 'USD' ? (converted * 100).round() / 100 : converted.roundToDouble();
  final text = display == 'USD' ? '\$${rounded.toStringAsFixed(rounded == rounded.roundToDouble() ? 0 : 2)}' : formatMoney(rounded, 'NGN');
  return 'about $text';
}
