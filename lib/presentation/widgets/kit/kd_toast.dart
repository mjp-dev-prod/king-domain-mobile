import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_card.dart';

enum ToastKind { ok, warn, error, info }

/// Brief confirmation at the top of the screen (brand v1 "designed states").
/// One at a time: a new toast replaces the current one. With an action (e.g.
/// Undo) it stays a little longer. Use for confirmations; errors that need
/// fixing belong inline next to their cause, not only in a toast.
class KdToast {
  KdToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _key = GlobalKey<_ToastViewState>();

  static void show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.ok,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _remove();
    if (kind == ToastKind.error) HapticFeedback.heavyImpact();
    _entry = OverlayEntry(
      builder: (_) => _ToastView(
        key: _key,
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                onAction();
                dismiss();
              },
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(actionLabel != null ? AppMotion.toastWithAction : AppMotion.toast, dismiss);
  }

  /// Animates the current toast out.
  static Future<void> dismiss() async {
    _timer?.cancel();
    final state = _key.currentState;
    if (state != null) await state.leave();
    _remove();
  }

  static void _remove() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatefulWidget {
  final String message;
  final ToastKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _ToastView({super.key, required this.message, required this.kind, this.actionLabel, this.onAction});

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), reverseDuration: const Duration(milliseconds: 240));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  Future<void> leave() => _c.reverse();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (widget.kind) {
      ToastKind.ok => (Icons.check_rounded, KdTone.ok),
      ToastKind.warn => (Icons.schedule_rounded, KdTone.warn),
      ToastKind.error => (Icons.error_outline_rounded, KdTone.bad),
      ToastKind.info => (Icons.info_outline_rounded, KdTone.brand),
    };
    final top = MediaQuery.paddingOf(context).top + 10;
    final anim = CurvedAnimation(parent: _c, curve: AppMotion.spring, reverseCurve: AppMotion.ease);
    return Positioned(
      top: top,
      left: 14,
      right: 14,
      child: SafeArea(
        top: false,
        child: Center(
          child: FadeTransition(
            opacity: _c,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -.4), end: Offset.zero).animate(anim),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  color: AppColors.surface3,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(10, 10, widget.actionLabel != null ? 8 : 14, 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, 16))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: toneSurface(tone), borderRadius: BorderRadius.circular(9)),
                          child: Icon(icon, size: 16, color: toneInk(tone)),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(widget.message, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        ),
                        if (widget.actionLabel != null) ...[
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: widget.onAction,
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.surface2,
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(widget.actionLabel!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
