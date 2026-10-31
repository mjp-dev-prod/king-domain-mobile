import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import 'kd_button.dart';
import 'kd_card.dart';

class EventCardAction {
  final String label;
  final FutureOr<void> Function() onPressed;
  final bool primary;
  const EventCardAction({required this.label, required this.onPressed, this.primary = false});
}

/// One job event in the contract room's timeline (PRD §4.7): funded, start
/// proof, draft, delivery, change request, extension, approval, payout. The
/// actions that event needs are taken right on the card.
class EventCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final DateTime at;
  final KdTone tone;
  final String? amount;
  final List<EventCardAction> actions;

  const EventCard({super.key, required this.icon, required this.title, required this.at, this.body, this.tone = KdTone.plain, this.amount, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final ink = tone == KdTone.plain ? AppColors.text2 : toneInk(tone);
    return KdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: tone == KdTone.plain ? AppColors.surface2 : toneSurface(tone), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title),
                    Text(formatAgo(at), style: AppTextStyles.hint),
                  ],
                ),
              ),
              if (amount != null)
                Text(amount!, style: AppTextStyles.title.copyWith(color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(body!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2, height: 1.5)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: actions[i].primary
                        ? KdButton(label: actions[i].label, height: AppDimensions.buttonHeightSm, onPressed: actions[i].onPressed)
                        : KdButton.secondary(label: actions[i].label, height: AppDimensions.buttonHeightSm, onPressed: actions[i].onPressed),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
