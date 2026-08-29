/// One 0-10 axis.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

/// A labelled 0-10 slider, used once for each of taste, smell and looks.
///
/// Whole steps only. The source notes were always written as integers out of
/// ten (`smak - 7/10`), and a slider that can land on 6,4 invites a precision
/// nobody actually has about a bowl of soup.
class ScoreSlider extends StatelessWidget {
  /// Creates a slider labelled [label] for [value].
  const ScoreSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The axis name, e.g. `Taste (smak)`.
  final String label;

  /// The current value, 0-10.
  final int value;

  /// Called with the new value.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          ScoreChip(score: value.toDouble()),
        ],
      ),
      Slider(
        value: value.toDouble(),
        min: kMinScore.toDouble(),
        max: kMaxScore.toDouble(),
        divisions: kMaxScore - kMinScore,
        label: '$value',
        onChanged: (raw) => onChanged(raw.round()),
      ),
      const SizedBox(height: AppSpacing.xs),
    ],
  );
}
