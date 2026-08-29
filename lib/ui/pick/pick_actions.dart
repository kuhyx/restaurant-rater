/// Rate / Skip, under the pick card.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The two things you can do with the offered dish.
class PickActions extends StatelessWidget {
  /// Creates the action row.
  const PickActions({
    required this.onRate,
    required this.onSkip,
    required this.canSkip,
    super.key,
  });

  /// Opens the rating screen for the offered dish.
  final VoidCallback onRate;

  /// Passes over the offered dish.
  final VoidCallback onSkip;

  /// Whether skipping would actually offer something else.
  final bool canSkip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: onRate,
          icon: const Icon(Icons.star_outline),
          label: const Text('Rate it'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          // Disabled rather than hidden: a button that vanishes is a layout
          // jump, and the caption below explains the state anyway.
          onPressed: canSkip ? onSkip : null,
          icon: const Icon(Icons.skip_next),
          label: const Text('Skip'),
        ),
        if (!canSkip) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nothing else left to switch to.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}
