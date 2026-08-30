/// Adding and editing one dish.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/money.dart';
import 'package:restaurant_rater/ui/rating/macros_fields.dart';

/// The dish name, price and menu-claimed macros the editor came back with.
typedef MenuItemDraft = ({String name, int? priceGrosz, Macros macros});

/// Asks for a dish's name and price. Returns null when dismissed.
Future<MenuItemDraft?> editMenuItemDialog(
  BuildContext context, {
  MenuItem? existing,
}) => showDialog<MenuItemDraft>(
  context: context,
  builder: (dialogContext) => _MenuItemDialog(existing: existing),
);

class _MenuItemDialog extends StatefulWidget {
  const _MenuItemDialog({this.existing});

  final MenuItem? existing;

  @override
  State<_MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<_MenuItemDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: switch (widget.existing?.priceGrosz) {
      final int grosz => formatPln(grosz).replaceAll(' zł', ''),
      null => '',
    },
  );
  late final TextEditingController _kcal = MacrosFields.controllerFor(
    widget.existing?.macros.kcal,
  );
  late final TextEditingController _protein = MacrosFields.controllerFor(
    widget.existing?.macros.proteinG,
  );
  late final TextEditingController _fat = MacrosFields.controllerFor(
    widget.existing?.macros.fatG,
  );
  late final TextEditingController _carbs = MacrosFields.controllerFor(
    widget.existing?.macros.carbsG,
  );

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _price,
      _kcal,
      _protein,
      _fat,
      _carbs,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    // parsePln returns null both for "blank" and for "unparseable", and both
    // mean the same thing here: no price recorded. Refusing to save over a
    // typo would trap the user in a dialog over a field that is optional.
    Navigator.of(context).pop((
      name: name,
      priceGrosz: parsePln(_price.text),
      macros: MacrosFields.read(
        kcal: _kcal,
        protein: _protein,
        fat: _fat,
        carbs: _carbs,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'New dish' : 'Edit dish'),
    // Scrollable: six fields do not fit a dialog on a phone in landscape,
    // and the overflow only shows up when the app runs, never when it
    // analyzes.
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Dish',
              hintText: 'tom kha z kurczakiem',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price',
              suffixText: 'zł',
              hintText: '24',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          // What the menu claims, not what you ate — the rating screen
          // pre-fills from these and lets you overwrite them.
          MacrosFields(
            kcal: _kcal,
            protein: _protein,
            fat: _fat,
            carbs: _carbs,
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _name.text.trim().isEmpty ? null : _submit,
        child: const Text('Save'),
      ),
    ],
  );
}
