import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'pressable.dart';

/// A labelled multi-line text field with a live character count that says
/// what's still needed ("4 more characters") instead of scolding. Reports
/// validity through [onValidChanged] so the screen can enable its button.
/// Limits match the backend (contractCore RULES.reasonLength: 10–1000).
class ReasonField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int min;
  final int max;
  final ValueChanged<bool>? onValidChanged;

  const ReasonField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.min = 10,
    this.max = 1000,
    this.onValidChanged,
  });

  static bool isValid(String text, {int min = 10, int max = 1000}) {
    final n = text.trim().length;
    return n >= min && n <= max;
  }

  @override
  State<ReasonField> createState() => _ReasonFieldState();
}

class _ReasonFieldState extends State<ReasonField> {
  bool? _lastValid;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final valid = ReasonField.isValid(widget.controller.text, min: widget.min, max: widget.max);
    if (valid != _lastValid) {
      _lastValid = valid;
      widget.onValidChanged?.call(valid);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.controller.text.trim().length;
    final short = n > 0 && n < widget.min;
    final missing = widget.min - n;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: widget.controller,
            minLines: 3,
            maxLines: 6,
            maxLength: widget.max,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: widget.hint,
              fillColor: AppColors.surface2,
              enabledBorder: short
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      borderSide: const BorderSide(color: AppColors.bad, width: 1.5),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  short ? '$missing more character${missing == 1 ? '' : 's'}' : '',
                  style: AppTextStyles.hint.copyWith(color: AppColors.bad),
                ),
              ),
              Text('$n/${widget.max}', style: AppTextStyles.hint),
            ],
          ),
        ],
      ),
    );
  }
}

/// − value + stepper, e.g. extra delivery days.
class DayStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String unit;

  const DayStepper({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.unit = 'day'});

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, int delta, String label) {
      final next = value + delta;
      final enabled = next >= min && next <= max;
      return Pressable(
        onTap: enabled ? () => onChanged(next) : null,
        haptic: true,
        scale: .9,
        semanticLabel: label,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : .35,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
            child: Icon(icon, color: AppColors.text),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
      child: Row(
        children: [
          step(Icons.remove_rounded, -1, 'Fewer ${unit}s'),
          Expanded(
            child: Text(
              '$value $unit${value == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          step(Icons.add_rounded, 1, 'More ${unit}s'),
        ],
      ),
    );
  }
}
