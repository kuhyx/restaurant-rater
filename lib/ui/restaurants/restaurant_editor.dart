/// Adding and renaming a restaurant.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/models/restaurant.dart';

/// The name and note the editor came back with.
typedef RestaurantDraft = ({String name, String? note});

/// Asks for a restaurant's name and note.
///
/// Returns null when dismissed. [existing] pre-fills the fields and switches
/// the wording to an edit.
Future<RestaurantDraft?> editRestaurantDialog(
  BuildContext context, {
  Restaurant? existing,
}) => showDialog<RestaurantDraft>(
  context: context,
  builder: (dialogContext) => _RestaurantDialog(existing: existing),
);

class _RestaurantDialog extends StatefulWidget {
  const _RestaurantDialog({this.existing});

  final Restaurant? existing;

  @override
  State<_RestaurantDialog> createState() => _RestaurantDialogState();
}

class _RestaurantDialogState extends State<_RestaurantDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    // A nameless restaurant is unfindable in the list, so Save simply does
    // nothing rather than creating one. The button is disabled too; this is
    // the guard for the keyboard's own submit action.
    if (name.isEmpty) return;
    final note = _note.text.trim();
    Navigator.of(
      context,
    ).pop((name: name, note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'New restaurant' : 'Edit restaurant'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          decoration: const InputDecoration(
            labelText: 'Note',
            hintText: 'address, district, "the one by the tram stop"',
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
