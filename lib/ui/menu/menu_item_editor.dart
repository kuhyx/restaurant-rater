/// Adding and editing one dish.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/money.dart';

/// The dish name and price the editor came back with.
typedef MenuItemDraft = ({String name, int? priceGrosz});

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

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    // parsePln returns null both for "blank" and for "unparseable", and both
    // mean the same thing here: no price recorded. Refusing to save over a
    // typo would trap the user in a dialog over a field that is optional.
    Navigator.of(
      context,
    ).pop((name: name, priceGrosz: parsePln(_price.text)));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'New dish' : 'Edit dish'),
    content: Column(
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
      ],
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
