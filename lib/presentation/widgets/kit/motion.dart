import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';

/// Content arriving: fades and rises into place once, after [delay]. Wrap the
/// cards of a screen with increasing delays for a short stagger.
class RiseIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const RiseIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.arrive);
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _start?.cancel();
      _c.value = 1;
    } else if (_c.value == 0 && _start == null) {
      _start = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: AppMotion.ease);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(a), child: widget.child),
    );
  }
}

/// A placeholder block that shimmers while content loads (lists and cards
/// whose shape is known). Spinners are only for inside the button that's
/// working.
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 12, this.width, this.radius = 6});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + 3 * _c.value - 1, 0),
            end: Alignment(1 + 3 * _c.value - 1, 0),
            colors: const [AppColors.surface2, AppColors.surface3, AppColors.surface2],
          ),
        ),
      ),
    );
  }
}

/// A card-shaped skeleton matching a job/contract card.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 110),
            SizedBox(height: 12),
            Skeleton(height: 16),
            SizedBox(height: 10),
            Skeleton(width: 180),
            SizedBox(height: 16),
            Skeleton(),
          ],
        ),
      ),
    );
  }
}
