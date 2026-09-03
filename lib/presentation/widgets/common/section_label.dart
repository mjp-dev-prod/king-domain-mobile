import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';

/// Uppercase, letter-spaced mono eyebrow label — see CLAUDE.md brand v0.
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppTextStyles.label);
  }
}
