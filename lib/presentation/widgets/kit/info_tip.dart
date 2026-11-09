import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/glossary.dart';
import 'kd_button.dart';
import 'kd_sheet.dart';
import 'pressable.dart';

/// A small "i" that explains a term in plain words when tapped (wording pass, 2026-11-09). It sits right next to the
/// word it explains, opens a short sheet, and is read out as "What is …?" to a screen reader. The words live in
/// [Glossary], so a term is explained the same way wherever it appears.
class InfoTip extends StatelessWidget {
  final Tip tip;
  const InfoTip(this.tip, {super.key});

  static Future<void> show(BuildContext context, Tip tip) => showKdSheet<void>(
    context,
    builder: (sheet) => KdSheetBody(
      title: tip.title,
      children: [
        const SizedBox(height: 10),
        Text(tip.body, style: AppTextStyles.bodyMedium.copyWith(height: 1.5)),
        const SizedBox(height: 20),
        KdButton.secondary(label: 'Got it', onPressed: () => Navigator.of(sheet).pop()),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => show(context, tip),
      semanticLabel: tip.title,
      // A finger-sized target around a small icon.
      child: const SizedBox(
        width: 36,
        height: 36,
        child: Center(child: Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryText)),
      ),
    );
  }
}

/// A heading with its tip beside it, so the explanation is found exactly where the word is.
class TitleWithTip extends StatelessWidget {
  final String title;
  final Tip tip;
  final TextStyle? style;
  const TitleWithTip(this.title, this.tip, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text(title, style: style ?? AppTextStyles.title)),
        const SizedBox(width: 2),
        InfoTip(tip),
      ],
    );
  }
}
