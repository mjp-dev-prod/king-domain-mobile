import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';

/// A piece of real work (proof, delivery), never decoration
/// (docs/features/imagery-surfaces.md). Shows a surface colour while loading,
/// fades the image in, and falls back to a file icon for non-images or
/// expired links. Signed links last 5 minutes, so callers re-fetch to refresh.
class WorkImage extends StatelessWidget {
  final String? url;
  final double radius;
  final int cacheWidth;
  final IconData fallbackIcon;

  const WorkImage({super.key, required this.url, this.radius = AppDimensions.radiusMd, this.cacheWidth = 400, this.fallbackIcon = Icons.description_outlined});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(color: AppColors.surface2, alignment: Alignment.center, child: Icon(fallbackIcon, color: AppColors.text3));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? fallback
          : Container(
              color: AppColors.surface2,
              child: Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                width: double.infinity,
                height: double.infinity,
                frameBuilder: (_, child, frame, sync) =>
                    sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: AppMotion.layout, child: child),
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
