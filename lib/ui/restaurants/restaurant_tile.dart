/// One row in the restaurants list.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/logic/stats.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

/// A restaurant, its progress through the menu, and its average score.
class RestaurantTile extends StatelessWidget {
  /// Creates a tile.
  const RestaurantTile({
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

  /// Tapping the row goes to the pick — the app's whole point is answering
  /// "what do I order here", so that is the default action rather than a menu
  /// listing the user has to step through first.
  final VoidCallback onTap;

  /// The trailing icon opens the menu for editing.
  final VoidCallback onEditMenu;

  @override
  Widget build(BuildContext context) {
    final mean = progress.mean;
    final note = restaurant.note;
    return ListTile(
      title: Text(restaurant.name),
      subtitle: Text(
        note == null || note.isEmpty
            ? progress.label
            : '$note  ·  ${progress.label}',
      ),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (mean != null) ScoreChip(score: mean),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Menu',
            onPressed: onEditMenu,
          ),
        ],
      ),
    );
  }
}
