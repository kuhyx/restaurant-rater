/// One rating in the history list.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/logic/scores.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/ui/common/photo_thumb.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

/// A tasting: dish, place, the three axes, and the photo if it is here.
class TastingTile extends StatelessWidget {
  /// Creates a tile.
  const TastingTile({
    required this.tasting,
    required this.dishName,
    required this.restaurantName,
    required this.photos,
    required this.onDelete,
    super.key,
  });

  /// The rating.
  final Tasting tasting;

  /// The dish's name, resolved by the caller.
  final String dishName;

  /// The restaurant's name, resolved by the caller.
  final String restaurantName;

  /// Where photos live on this device.
  final PhotoStore photos;

  /// Deletes this rating, after confirmation.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: tasting.photoName == null
        ? null
        : PhotoThumb(photos: photos, photoName: tasting.photoName),
    title: Text(dishName),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(restaurantName),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            ScoreChip(score: tasting.taste.toDouble(), label: 'smak'),
            ScoreChip(score: tasting.smell.toDouble(), label: 'zapach'),
            ScoreChip(score: tasting.looks.toDouble(), label: 'estetyka'),
          ],
        ),
      ],
    ),
    isThreeLine: true,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ScoreChip(score: overallOf(tasting)),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete rating',
          onPressed: onDelete,
        ),
      ],
    ),
  );
}
