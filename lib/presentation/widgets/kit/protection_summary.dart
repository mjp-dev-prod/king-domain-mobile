import 'package:flutter/material.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import 'kd_card.dart';

class ProtectionLine {
  final IconData icon;
  final String title;
  final String body;
  const ProtectionLine({required this.icon, required this.title, required this.body});
}

/// Every rule a client agrees to before paying for a one-delivery job (PRD §3.2 step 6,
/// decisions D8, D33, D35, and the agreed payment rules).
List<ProtectionLine> oneDeliveryProtection({required num price, required num fee, required int changeRounds, required int startSharePercent}) => [
  ProtectionLine(
    icon: Icons.lock_outline_rounded,
    title: 'Your money is held',
    body: '${formatNaira(price)} stays with ${AppBrand.name} until you approve the work. The ${formatNaira(fee)} fee is ours and is not refunded.',
  ),
  ProtectionLine(
    icon: Icons.flag_outlined,
    title: 'Proof the work has started',
    body: "Early on, the talent sends a start proof in a fixed format. You have 24 hours to accept it or say it isn't a real start. Once accepted, $startSharePercent% is paid to them.",
  ),
  ProtectionLine(
    icon: Icons.replay_rounded,
    title: 'Changes included',
    body: "Up to $changeRounds rounds of changes after delivery. If you don't respond within 3 days of a delivery, it is approved.",
  ),
  const ProtectionLine(
    icon: Icons.event_busy_outlined,
    title: "If the work doesn't come",
    body: 'Three days past the delivery date with nothing delivered and no extension, you can cancel for a full refund of the price. If the talent stops after the start proof, you keep that work and get the rest back; the start share is not refunded.',
  ),
  const ProtectionLine(
    icon: Icons.gavel_outlined,
    title: 'If you disagree',
    body: 'Use "Something\'s wrong" to agree a way out. If that fails, the team decides within 5 days, free, with written reasons. The decision is final.',
  ),
];

/// The protection block on the pay screen: plain rules, the total in gold.
class ProtectionSummary extends StatelessWidget {
  final List<ProtectionLine> lines;
  final num total;
  const ProtectionSummary({super.key, required this.lines, required this.total});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('You pay', style: AppTextStyles.title)),
            Text(formatNaira(total), style: AppTextStyles.h3.copyWith(color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
          const SizedBox(height: 14),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(l.icon, size: 20, color: AppColors.primaryText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.title, style: AppTextStyles.title),
                    const SizedBox(height: 2),
                    Text(l.body, style: AppTextStyles.bodySmall.copyWith(height: 1.45)),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
