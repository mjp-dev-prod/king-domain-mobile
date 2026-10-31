import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_button.dart';
import 'kd_fields.dart';
import 'kd_sheet.dart';
import 'pressable.dart';

class ReasonCode {
  final String code;
  final String label;
  final bool needsNote;
  const ReasonCode({required this.code, required this.label, this.needsNote = false});
}

class ReasonChoice {
  final String code;
  final String note;
  const ReasonChoice({required this.code, required this.note});
}

/// Picks a structured reason (and a note when needed) for any action that
/// must say why: declining, objecting to a start proof, "something's wrong",
/// reporting. Free text alone is never enough (admin tools doc §3).
Future<ReasonChoice?> showReasonSheet(
  BuildContext context, {
  required String title,
  String? lead,
  required List<ReasonCode> codes,
  required String confirmLabel,
  int noteMin = 10,
  int noteMax = 500,
}) {
  return showKdSheet<ReasonChoice>(
    context,
    builder: (sheet) => _ReasonBody(title: title, lead: lead, codes: codes, confirmLabel: confirmLabel, noteMin: noteMin, noteMax: noteMax),
  );
}

class _ReasonBody extends StatefulWidget {
  final String title;
  final String? lead;
  final List<ReasonCode> codes;
  final String confirmLabel;
  final int noteMin;
  final int noteMax;
  const _ReasonBody({required this.title, required this.lead, required this.codes, required this.confirmLabel, required this.noteMin, required this.noteMax});

  @override
  State<_ReasonBody> createState() => _ReasonBodyState();
}

class _ReasonBodyState extends State<_ReasonBody> {
  final _note = TextEditingController();
  ReasonCode? _picked;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ready {
    final picked = _picked;
    if (picked == null) return false;
    if (!picked.needsNote) return true;
    return ReasonField.isValid(_note.text, min: widget.noteMin, max: widget.noteMax);
  }

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: widget.title,
      lead: widget.lead,
      children: [
        const SizedBox(height: 12),
        for (final c in widget.codes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: Pressable(
              onTap: () => setState(() => _picked = c),
              semanticLabel: c.label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _picked == c ? AppColors.primarySoft : AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(children: [
                  Icon(
                    _picked == c ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 20,
                    color: _picked == c ? AppColors.primaryText : AppColors.text3,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.label, style: AppTextStyles.bodyMedium)),
                ]),
              ),
            ),
          ),
        if (_picked?.needsNote ?? false) ...[
          const SizedBox(height: 4),
          ReasonField(controller: _note, label: 'Tell them more', min: widget.noteMin, max: widget.noteMax),
        ],
        const SizedBox(height: 12),
        KdButton(
          label: widget.confirmLabel,
          onPressed: _ready ? () => Navigator.of(context).pop(ReasonChoice(code: _picked!.code, note: _note.text.trim())) : null,
        ),
      ],
    );
  }
}
