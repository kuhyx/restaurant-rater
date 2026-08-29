/// A compact 0-10 score, coloured by how good it is.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/logic/scores.dart';

/// Shows [score] out of ten as a small tinted chip.
///
/// The hue is the whole point: a list of dishes is scanned, not read, and a
/// column of identical grey numbers gives the eye nothing to catch on.
class ScoreChip extends StatelessWidget {
  /// Creates a chip for [score] on the 0-10 scale.
  const ScoreChip({required this.score, this.label, super.key});

  /// The value, 0-10.
  final double score;

  /// Optional caption shown before the number, e.g. `smak`.
  final String? label;

  /// The hue for [score].
  ///
  /// Thresholds rather than a gradient: the point is a verdict at a glance,
  /// and a continuous ramp makes 5,4 and 5,6 indistinguishable, which is
  /// exactly the distinction worth seeing.
  static Color colorFor(double score) {
    if (score >= 7) return AppPalette.success;
    if (score >= 4) return AppPalette.warning;
    return AppPalette.danger;
  }

  @override
  Widget build(BuildContext context) {
    final tint = colorFor(score);
    final caption = label;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        caption == null ? formatScore(score) : '$caption ${formatScore(score)}',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: tint),
      ),
    );
  }
}
