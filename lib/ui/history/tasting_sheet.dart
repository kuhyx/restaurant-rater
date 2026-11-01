/// The details of one rating, opened from its tile.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/logic/scores.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

/// Shows [tasting] in a bottom sheet; resolves true when the user asks to
/// delete it.
Future<bool> showTastingSheet(
  BuildContext context, {
  required Tasting tasting,
  required String dishName,
  required String restaurantName,
}) async {
  final delete = await showModalBottomSheet<bool>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    dishName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ScoreChip(score: overallOf(tasting)),
              ],
            ),
            Text(restaurantName),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      ScoreChip(score: tasting.taste.toDouble(), label: 'smak'),
                      ScoreChip(
                        score: tasting.smell.toDouble(),
                        label: 'zapach',
                      ),
                      ScoreChip(
                        score: tasting.looks.toDouble(),
                        label: 'estetyka',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete rating',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return delete ?? false;
}
