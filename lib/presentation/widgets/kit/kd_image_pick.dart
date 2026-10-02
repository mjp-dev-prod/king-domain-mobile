import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import 'pressable.dart';

/// Attach one image from the gallery, then see it: an empty drop area, or
/// the picked image with Replace and Remove. Resized on the device (max
/// 2400px) so uploads stay well under the server's 10 MB limit.
class ImagePickField extends StatelessWidget {
  final XFile? file;
  final ValueChanged<XFile?> onChanged;
  final String emptyLabel;

  const ImagePickField({super.key, required this.file, required this.onChanged, this.emptyLabel = 'Attach an image'});

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 90);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final f = file;
    return AnimatedSwitcher(
      duration: AppMotion.state,
      child: f == null
          ? Pressable(
              key: const ValueKey('empty'),
              onTap: _pick,
              semanticLabel: emptyLabel,
              child: Container(
                height: 120,
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryText, size: 28),
                    const SizedBox(height: 8),
                    Text(emptyLabel, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    Text('PNG or JPG, up to 10 MB', style: AppTextStyles.hint),
                  ],
                ),
              ),
            )
          : ClipRRect(
              key: ValueKey(f.path),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(File(f.path), fit: BoxFit.cover, cacheWidth: 900, width: double.infinity),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(AppDimensions.radiusPill)),
                            child: Text(f.name, style: AppTextStyles.hint.copyWith(color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoundButton(icon: Icons.swap_horiz_rounded, label: 'Replace', onTap: _pick),
                        const SizedBox(width: 6),
                        _RoundButton(icon: Icons.close_rounded, label: 'Remove', onTap: () => onChanged(null)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: AppColors.surface3, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: AppColors.text),
        ),
      );
}
