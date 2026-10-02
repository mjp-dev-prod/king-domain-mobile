import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import 'pressable.dart';

/// Throw this from a button's action after you've shown the failure to the
/// user (toast or inline): the button returns to idle, skips its success
/// state, and doesn't report it as a crash.
class ShownError implements Exception {
  const ShownError();
}

enum KdButtonVariant {
  /// The one main action on a screen. Violet, with the only glow allowed.
  primary,
  /// A filled surface: the secondary action under a primary one.
  secondary,
  /// Violet-tinted, for a positive action that isn't the screen's main one.
  soft,
  /// Destructive or final ("Decline", "Sign out").
  danger,
}

/// The button every rebuilt screen uses. Give it an async [onPressed] and it
/// manages its own states: a spinner while the work runs (held at least
/// [AppMotion.minLoading] so it never flashes), then, if [successLabel] is
/// set, a short success state before returning to idle. Errors are the
/// caller's to show (toast or inline); the button just returns to idle.
class KdButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final FutureOr<void> Function()? onPressed;
  final KdButtonVariant variant;
  final String? busyLabel;
  final String? successLabel;
  final double height;

  const KdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = KdButtonVariant.primary,
    this.busyLabel,
    this.successLabel,
    this.height = AppDimensions.buttonHeightLg,
  });

  const KdButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busyLabel,
    this.successLabel,
    this.height = AppDimensions.buttonHeightMd,
  }) : variant = KdButtonVariant.secondary;

  @override
  State<KdButton> createState() => _KdButtonState();
}

enum _Phase { idle, busy, done }

class _KdButtonState extends State<KdButton> {
  _Phase _phase = _Phase.idle;

  Future<void> _run() async {
    if (_phase != _Phase.idle || widget.onPressed == null) return;
    final result = widget.onPressed!();
    if (result is! Future) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _phase = _Phase.busy);
    final started = DateTime.now();
    var ok = true;
    try {
      await result;
    } on ShownError {
      ok = false;
    } catch (error, stack) {
      ok = false;
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'KdButton'));
    }
    final held = DateTime.now().difference(started);
    if (held < AppMotion.minLoading) await Future.delayed(AppMotion.minLoading - held);
    if (!mounted) return;
    if (ok && widget.successLabel != null) {
      HapticFeedback.mediumImpact();
      setState(() => _phase = _Phase.done);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
    }
    setState(() => _phase = _Phase.idle);
  }

  ({Color bg, Color fg}) get _colors => switch ((widget.variant, _phase)) {
    (_, _Phase.done) => (bg: AppColors.ok, fg: const Color(0xFF04140D)),
    (KdButtonVariant.primary, _) => (bg: AppColors.primary, fg: AppColors.onPrimary),
    (KdButtonVariant.secondary, _) => (bg: AppColors.surface1, fg: AppColors.text),
    (KdButtonVariant.soft, _) => (bg: AppColors.primarySoft, fg: AppColors.primaryText),
    (KdButtonVariant.danger, _) => (bg: AppColors.badSoft, fg: AppColors.bad),
  };

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final c = disabled ? (bg: AppColors.surface2, fg: AppColors.text3) : _colors;
    final glow = !disabled && widget.variant == KdButtonVariant.primary;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final Widget content = switch (_phase) {
      _Phase.busy => Row(
        key: const ValueKey('busy'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.fg)),
          if (widget.busyLabel != null) ...[const SizedBox(width: 10), Text(widget.busyLabel!)],
        ],
      ),
      _Phase.done => Row(
        key: const ValueKey('done'),
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.check_rounded, size: 20, color: c.fg), const SizedBox(width: 8), Text(widget.successLabel!)],
      ),
      _Phase.idle => Row(
        key: const ValueKey('idle'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: c.fg), const SizedBox(width: 10)],
          Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    };

    return Pressable(
      onTap: disabled || _phase != _Phase.idle ? null : _run,
      semanticLabel: _phase == _Phase.busy ? (widget.busyLabel ?? 'Working') : null,
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : AppMotion.state,
        curve: AppMotion.ease,
        height: widget.height,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: glow ? const [BoxShadow(color: AppColors.primaryGlow, blurRadius: 28, offset: Offset(0, 12))] : null,
        ),
        child: DefaultTextStyle.merge(
          style: AppTextStyles.button.copyWith(color: c.fg, fontSize: widget.height < AppDimensions.buttonHeightLg ? 15 : 16),
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : AppMotion.state,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(anim), child: child),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
