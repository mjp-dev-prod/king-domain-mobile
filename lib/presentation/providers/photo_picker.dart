import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A picture chosen on the phone, already shrunk, ready to upload.
class PickedPhoto {
  final Uint8List bytes;
  final String name;
  const PickedPhoto({required this.bytes, required this.name});
}

/// Where a profile photo comes from. A seam so tests don't need a phone.
abstract class PhotoPicker {
  /// The chosen picture, or null when the person backed out.
  Future<PickedPhoto?> pick(ImageSource source);
}

/// The real thing: the phone's gallery or camera. The picture is re-encoded at most 800 px on a side
/// and quality 85 before it leaves the phone, so uploads stay small (the server's limit is 5 MB).
class DevicePhotoPicker implements PhotoPicker {
  const DevicePhotoPicker();

  @override
  Future<PickedPhoto?> pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), name: file.name);
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => const DevicePhotoPicker());
