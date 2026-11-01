/// One dish tile in the menu grid.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/money.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

/// A dish, its price, and whether it has been eaten or passed over.
class MenuItemTile extends StatelessWidget {
  /// Creates a tile.
  const new({
    required this.item,
    required this.score,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  /// The dish.
  final MenuItem item;

  /// Its mean overall, or null when it has never been rated.
  final double? score;

  /// Opens the editor (tap).
  final VoidCallback onEdit;

  /// Deletes the dish, after confirmation (long-press: a destructive action
  /// has no business being one stray tap away on a tile this small).
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = item.priceGrosz;
    final kcal = item.macros.kcal;
    final mean = score;
    final meta = <String>[
      if (price != null) formatPln(price),
      // The menu's claim, shown here so a dish you have not eaten yet still
      // says what it costs you.
      if (kcal != null) '${kcal.round()} kcal',
      if (mean == null) 'not tried yet',
      // Only worth saying while it is still unrated — a skip on a dish you
      // have since eaten is history, not a state.
      if (mean == null && item.isSkipped) 'skipped',
    ];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(
                meta.join('  ·  '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
              if (mean != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                ScoreChip(score: mean),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
