import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_motion.dart';

/// Press feedback for anything tappable (brand v1: press-scale, no ripples).
/// Scales down while held, gives a light haptic tick on [haptic] taps, and is
/// announced as a button to screen readers.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = AppMotion.pressScale,
    this.haptic = false,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down && enabled ? widget.scale : 1,
          duration: reduce ? Duration.zero : AppMotion.press,
          curve: AppMotion.ease,
          child: widget.child,
        ),
      ),
    );
  }
}
