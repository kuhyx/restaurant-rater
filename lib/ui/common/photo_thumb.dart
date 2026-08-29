/// Showing a dish photo, including when its bytes are not on this device.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/photos/photo_store.dart';

/// Renders [photoName] from [photos], or an honest placeholder.
///
/// Three states, and the third is the one that matters. Ratings sync but photo
/// files do not — the transport is a JSON tree and blobs have no business in
/// it — so a tasting rated on the other phone arrives here complete except for
/// its picture. That is a normal, permanent, expected state, so it gets a
/// caption saying exactly what happened rather than a broken-image glyph
/// (which reads as corruption) or nothing at all (which reads as "no photo was
/// ever taken", the opposite of the truth).
class PhotoThumb extends StatelessWidget {
  /// Creates a thumbnail.
  const PhotoThumb({
    required this.photos,
    required this.photoName,
    this.size = 56,
    super.key,
  });

  /// Where photos live on this device.
  final PhotoStore photos;

  /// The filename recorded on the tasting, or null when none was taken.
  final String? photoName;

  /// Edge length of the square thumbnail.
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = photoName;
    if (name == null) return const SizedBox.shrink();

    final radius = BorderRadius.circular(AppRadius.sm);
    if (!photos.exists(name)) {
      return _elsewhere(context, radius);
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        photos.fileFor(name),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // The file existed a moment ago or we would not be here; if it has
        // gone since, fall back to the same honest placeholder rather than
        // letting Flutter paint its broken-image icon.
        errorBuilder: (context, _, _) => _elsewhere(context, radius),
      ),
    );
  }

  Widget _elsewhere(BuildContext context, BorderRadius radius) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Photo is on another device',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: Icon(
          Icons.phone_iphone,
          size: size / 2.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
