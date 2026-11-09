import 'package:flutter/material.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/glossary.dart';
import '../../../core/formatting/currency.dart';
import 'info_tip.dart';
import 'kd_card.dart';

class ProtectionLine {
  final IconData icon;
  final String title;
  final String body;
  final Tip? tip;
  const ProtectionLine({required this.icon, required this.title, required this.body, this.tip});
}

/// Every rule a client agrees to before paying for a one-delivery job (PRD §3.2 step 6,
/// decisions D8, D33, D35, and the agreed payment rules).
List<ProtectionLine> oneDeliveryProtection({required num price, required num fee, required int changeRounds, required int startSharePercent}) => [
  ProtectionLine(
    icon: Icons.lock_outline_rounded,
    title: 'Your money is held',
    body: '${formatNaira(price)} stays with ${AppBrand.name} until you approve the work. The ${formatNaira(fee)} fee is ${AppBrand.name}\'s, and it is not refunded.',
    tip: Glossary.heldPayment,
  ),
  ProtectionLine(
    icon: Icons.flag_outlined,
    title: 'Proof the work has started',
    body: "Early on, the talent sends a first sample, called a start proof. You have 24 hours to accept it, or to say it is not a real start. When you accept, $startSharePercent% is paid to the talent.",
    tip: Glossary.startProof,
  ),
  ProtectionLine(
    icon: Icons.replay_rounded,
    title: 'Changes included',
    body: "You can ask for changes up to $changeRounds times after delivery. If you do not answer within 3 days of a delivery, it is approved.",
    tip: Glossary.changeRounds,
  ),
  const ProtectionLine(
    icon: Icons.event_busy_outlined,
    title: "If the work doesn't come",
    body: 'If the delivery date passes by 3 days with nothing delivered and no extension, you can cancel and get the full price back. If the talent stops after the start proof, you keep the work done and get the rest back. The start share is not refunded.',
  ),
  const ProtectionLine(
    icon: Icons.gavel_outlined,
    title: 'If you disagree',
    body: 'Tap "Something\'s wrong" to agree a way out with the talent. If that does not work, our team decides within 5 days, for free, and writes down the reasons. Their decision is final.',
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
                    l.tip == null ? Text(l.title, style: AppTextStyles.title) : TitleWithTip(l.title, l.tip!),
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
