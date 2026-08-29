/// Taking or choosing the dish photo.
library;

import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/ui/common/photo_thumb.dart';

/// Returns a picked image, or null when the user backed out.
///
/// The seam that keeps this widget testable. `ImagePicker` talks over a
/// platform channel that does not exist under `flutter_test`, so the real one
/// is only ever constructed inside [defaultPickPhoto] and a test injects a
/// function returning a temp file instead.
typedef PickPhoto = Future<XFile?> Function(ImageSource source);

/// The real picker: camera or gallery, downscaled on the way in.
///
/// 1600px and quality 85 turn a 6 MB Pixel original into roughly 300 KB. These
/// are photos of soup for a personal record, and the full-resolution original
/// buys nothing while filling the device.
Future<XFile?> defaultPickPhoto(ImageSource source) => ImagePicker().pickImage(
  source: source,
  maxWidth: 1600,
  imageQuality: 85,
);

/// Shows the current photo and offers to replace or remove it.
class PhotoField extends StatelessWidget {
  /// Creates the field.
  const PhotoField({
    required this.photos,
    required this.photoName,
    required this.onPicked,
    required this.onCleared,
    this.pickPhoto = defaultPickPhoto,
    super.key,
  });

  /// Where photos live on this device.
  final PhotoStore photos;

  /// The photo already attached, if any.
  final String? photoName;

  /// Called with the picked file, for the caller to copy into [photos].
  final ValueChanged<File> onPicked;

  /// Called when the photo is removed.
  final VoidCallback onCleared;

  /// How a photo is obtained. Injected in tests.
  final PickPhoto pickPhoto;

  Future<void> _pick(ImageSource source) async {
    final picked = await pickPhoto(source);
    if (picked == null) return;
    onPicked(File(picked.path));
  }

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      PhotoThumb(photos: photos, photoName: photoName, size: 72),
      if (photoName != null) const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
            if (photoName != null)
              TextButton.icon(
                onPressed: onCleared,
                icon: const Icon(Icons.close),
                label: const Text('Remove'),
              ),
          ],
        ),
      ),
    ],
  );
}
