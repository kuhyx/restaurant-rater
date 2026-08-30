/// One dish in the menu list.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/money.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

/// A dish, its price, and whether it has been eaten or passed over.
class MenuItemTile extends StatelessWidget {
  /// Creates a tile.
  const MenuItemTile({
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

  /// Opens the editor.
  final VoidCallback onEdit;

  /// Deletes the dish, after confirmation.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final price = item.priceGrosz;
    final kcal = item.macros.kcal;
    final mean = score;
    return ListTile(
      title: Text(item.name),
      subtitle: Text(
        <String>[
          if (price != null) formatPln(price),
          // The menu's claim, shown here so a dish you have not eaten yet
          // still says what it costs you.
          if (kcal != null) '${kcal.round()} kcal',
          if (mean == null) 'not tried yet',
          // Only worth saying while it is still unrated — a skip on a dish you
          // have since eaten is history, not a state.
          if (mean == null && item.isSkipped) 'skipped',
        ].join('  ·  '),
      ),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (mean != null) ScoreChip(score: mean),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete dish',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
