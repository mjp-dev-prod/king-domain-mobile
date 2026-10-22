import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/photo_picker.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/pressable.dart';

/// The signed-in person's own picture, with a camera mark: tap it to choose, take or remove a profile
/// photo. Profile photos are public (everyone can see them), and the sheet says so.
class ProfilePhotoButton extends ConsumerWidget {
  final double size;
  /// Optional progress ring (the talent's profile completion).
  final double? ring;
  const ProfilePhotoButton({super.key, this.size = 84, this.ring});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final inset = ring == null ? 0.0 : 6.0; // the ring adds 6 px around the picture
    return Pressable(
      onTap: () => _openSheet(context, ref, hasPhoto: user?.photoUrl != null),
      semanticLabel: 'Change profile photo',
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(name: user?.fullName ?? '', photoUrl: user?.photoUrl, size: size, ring: ring),
            Positioned(
              right: inset,
              bottom: inset,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle, border: Border.all(color: AppColors.ground, width: 2)),
                child: const Icon(Icons.photo_camera_outlined, size: 15, color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref, {required bool hasPhoto}) {
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Profile photo',
        lead: 'Everyone on ${AppBrand.name} can see it.',
        children: [
          const SizedBox(height: 16),
          KdButton(
            label: 'Choose from gallery',
            icon: Icons.photo_library_outlined,
            variant: KdButtonVariant.soft,
            onPressed: () => _pickAndUpload(sheet, ref, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
          KdButton(
            label: 'Take a photo',
            icon: Icons.photo_camera_outlined,
            variant: KdButtonVariant.soft,
            onPressed: () => _pickAndUpload(sheet, ref, ImageSource.camera),
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 8),
            KdButton(label: 'Remove photo', icon: Icons.delete_outline_rounded, variant: KdButtonVariant.danger, onPressed: () => _remove(sheet, ref)),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext sheet, WidgetRef ref, ImageSource source) async {
    PickedPhoto? photo;
    try {
      photo = await ref.read(photoPickerProvider).pick(source);
    } catch (_) {
      final what = source == ImageSource.camera ? 'camera' : 'photos';
      if (sheet.mounted) KdToast.show(sheet, 'Couldn\'t open your $what. Check the app\'s permissions and try again.', kind: ToastKind.error);
      throw const ShownError();
    }
    if (photo == null) {
      if (sheet.mounted) Navigator.of(sheet).pop(); // they backed out: nothing to say
      return;
    }
    try {
      await ref.read(authProvider.notifier).setPhoto(photo.bytes, photo.name);
    } on ApiException catch (e) {
      if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (!sheet.mounted) return;
    Navigator.of(sheet).pop();
    KdToast.show(sheet, 'Photo updated.');
  }

  Future<void> _remove(BuildContext sheet, WidgetRef ref) async {
    try {
      await ref.read(authProvider.notifier).removePhoto();
    } on ApiException catch (e) {
      if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (!sheet.mounted) return;
    Navigator.of(sheet).pop();
    KdToast.show(sheet, 'Photo removed.');
  }
}
