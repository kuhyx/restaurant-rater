/// Sizing helpers for screens that must fit one phone screen.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Bottom padding that keeps the last row of a grid clear of the FAB.
///
/// A 56 dp FAB plus its 16 dp margin, plus a little air, so no tile is ever
/// hidden under it.
const double kFabClearance = 88;

/// Grid padding around the cells; [fab] leaves room for a FAB below them.
EdgeInsets fitGridPadding({bool fab = false}) => EdgeInsets.fromLTRB(
  AppSpacing.md,
  AppSpacing.sm,
  AppSpacing.md,
  fab ? kFabClearance : AppSpacing.sm,
);

/// Height of [lines] lines of [style], as the user's text scale will draw them.
///
/// Measured with a [TextPainter] rather than guessed from the font size, so a
/// larger system font cannot clip a caption under a tile.
double textBlockHeight(BuildContext context, TextStyle? style, int lines) {
  final painter = TextPainter(
    text: TextSpan(text: 'Ag', style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final height = painter.height * lines;
  painter.dispose();
  return height;
}
