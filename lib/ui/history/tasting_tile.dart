/// One rating tile in the history grid.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/logic/scores.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/ui/common/photo_thumb.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

/// Lines of dish name under the photo.
const int kTastingLabelLines = 2;

/// A tasting as a photo with its overall score, and the dish name below.
///
/// The restaurant, the three axes and the delete action sit one tap away in
/// the sheet this opens, so nothing is dropped, only moved off the grid.
class TastingTile extends StatelessWidget {
  /// Creates a tile.
  const new({
    required this.tasting,
    required this.dishName,
    required this.photos,
    required this.labelHeight,
    required this.onTap,
    super.key,
  });

  /// The rating.
  final Tasting tasting;

  /// The dish's name, resolved by the caller.
  final String dishName;

  /// Where photos live on this device.
  final PhotoStore photos;

  /// Height reserved for the name, from the real text metrics.
  final double labelHeight;

  /// Opens the details sheet.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (tasting.photoName == null)
                  ColoredBox(color: scheme.surfaceContainerHighest)
                else
                  PhotoThumb(photos: photos, photoName: tasting.photoName),
                Positioned(
                  right: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: ScoreChip(score: overallOf(tasting)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: labelHeight,
            child: Text(
              dishName,
              maxLines: kTastingLabelLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
