/// What an import is about to write, before it writes it.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/logic/menu_import.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/money.dart';

/// Counts dishes in words that read like words: `1 dish`, `2 dishes`.
String dishCount(int count) => count == 1 ? '1 dish' : '$count dishes';

/// The parsed dishes and every complaint the parse produced.
///
/// Both halves matter. A preview that showed only the dishes it understood
/// would quietly lose the two the model garbled, and the menu would come out
/// short with nothing on screen ever having said so.
class ImportPreview extends StatelessWidget {
  /// Creates the preview.
  const ImportPreview({
    required this.menu,
    required this.dishes,
    required this.extraWarnings,
    super.key,
  });

  /// The parse result, for its error and its own warnings.
  final ImportedMenu menu;

  /// The dishes that will actually be written, after removing any already on
  /// the target's menu.
  final List<MenuDraft> dishes;

  /// Warnings that depend on the chosen target rather than on the JSON.
  final List<String> extraWarnings;

  @override
  Widget build(BuildContext context) {
    final error = menu.error;
    final warnings = <String>[...menu.warnings, ...extraWarnings];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          dishes.isEmpty ? 'Preview' : 'Preview — ${dishCount(dishes.length)}',
        ),
        if (error != null) _Warning(error, isError: true),
        for (final dish in dishes) _DishRow(dish),
        if (error == null && dishes.isEmpty && menu.dishes.isNotEmpty)
          const _Warning('Every dish is already on this menu.'),
        for (final warning in warnings) _Warning(warning),
      ],
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow(this.dish);

  final MenuDraft dish;

  @override
  Widget build(BuildContext context) {
    final price = dish.priceGrosz;
    final kcal = dish.macros.kcal;
    final details = <String>[
      if (price != null) formatPln(price),
      if (kcal != null) '${kcal.round()} kcal',
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(dish.name),
      subtitle: details.isEmpty ? null : Text(details.join('  ·  ')),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.message, {this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.warning_amber,
            size: AppSpacing.md,
            color: isError ? colors.danger : colors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
