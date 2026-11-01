/// One tile in the restaurants grid.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/logic/stats.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

/// A restaurant, its progress through the menu, and its average score.
class RestaurantTile extends StatelessWidget {
  /// Creates a tile.
  const new({
    required this.restaurant,
    required this.progress,
    required this.onTap,
    required this.onEditMenu,
    super.key,
  });

  /// The place.
  final Restaurant restaurant;

  /// How much of its menu has been eaten.
  final RestaurantProgress progress;

  /// Tapping the tile goes to the pick — the app's whole point is answering
  /// "what do I order here", so that is the default action rather than a menu
  /// listing the user has to step through first.
  final VoidCallback onTap;

  /// The corner icon opens the menu for editing.
  final VoidCallback onEditMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mean = progress.mean;
    final note = restaurant.note;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        restaurant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restaurant_menu),
                    tooltip: 'Menu',
                    onPressed: onEditMenu,
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Text(
                    note == null || note.isEmpty
                        ? progress.label
                        : '$note  ·  ${progress.label}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              if (mean != null) ScoreChip(score: mean),
            ],
          ),
        ),
      ),
    );
  }
}
