import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_card.dart';

/// A small status tag. [pulse] adds a breathing dot for "live / waiting".
class StatusPill extends StatelessWidget {
  final String label;
  final KdTone tone;
  final IconData? icon;
  final bool pulse;

  const StatusPill(this.label, {super.key, this.tone = KdTone.plain, this.icon, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    final ink = tone == KdTone.plain ? AppColors.text2 : toneInk(tone);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: tone == KdTone.plain ? AppColors.surface2 : toneSurface(tone),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[PulseDot(color: ink), const SizedBox(width: 6)],
          if (icon != null) ...[Icon(icon, size: 14, color: ink), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The breathing dot used for "waiting" and "live" states.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, required this.color, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value < .5 ? _c.value * 2 : (1 - _c.value) * 2);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .45 * (1 - t)), spreadRadius: 5 * t)],
          ),
        );
      },
    );
  }
}
