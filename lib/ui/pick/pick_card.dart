/// The big "eat this" card.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/logic/pick_dish.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/money.dart';

/// Shows the chosen dish, its price, and why it was chosen.
class PickCard extends StatelessWidget {
  /// Creates the card for [item].
  const PickCard({required this.item, required this.reason, super.key});

  /// The dish to eat.
  final MenuItem item;

  /// Why this one.
  final PickReason reason;

  /// The line under the dish name explaining the choice.
  ///
  /// Worth the words: "next on the menu" and "you've eaten everything, so
  /// here's the one you've gone longest without" are very different things to
  /// be told while standing at a counter, and a card that just names a dish
  /// leaves the user guessing whether the app is stuck.
  static String captionFor(PickReason reason) => switch (reason) {
    PickReason.emptyMenu => '',
    PickReason.sticky => 'Still on this one',
    PickReason.nextUnrated => 'Next on the menu',
    PickReason.skippedFallback => 'Back round to one you skipped',
    PickReason.roundTwo => "Everything's been tried — longest since this one",
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = item.priceGrosz;
    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              captionFor(reason).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(item.name, style: theme.textTheme.headlineSmall),
            if (price != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatPln(price),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
