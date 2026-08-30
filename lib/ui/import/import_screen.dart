/// Pasting a menu in, instead of typing it in.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/logic/menu_import.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/ui/import/import_preview.dart';

/// Copy a prompt, photograph a menu, paste the answer back.
///
/// The whole screen is a preview of a write that has not happened yet: nothing
/// reaches the repository until Import is pressed, so a paste that turns out
/// to be the wrong menu costs a Cancel rather than a cleanup.
class ImportScreen extends StatefulWidget {
  /// Creates the import screen.
  const ImportScreen({required this.repository, super.key});

  /// The data.
  final RaterRepository repository;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final TextEditingController _json = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();

  /// The restaurant to append to, or null for "new restaurant".
  String? _targetId;

  /// Whether the user has edited the name, and so owns it from now on.
  ///
  /// Without this, re-parsing after every keystroke in the JSON box would
  /// stamp the pasted name back over a correction the user had just made.
  bool _nameIsMine = false;

  ImportedMenu _parsed = parseMenuImport('');
  bool _importing = false;

  @override
  void dispose() {
    _json.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _reparse() {
    final parsed = parseMenuImport(_json.text);
    setState(() {
      _parsed = parsed;
      if (!_nameIsMine) {
        _name.text = parsed.restaurantName ?? '';
        _note.text = parsed.restaurantNote ?? '';
      }
    });
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: kMenuImportPrompt));
    if (!mounted) return;
    showToast(context, 'Prompt copied. Send it with photos of the menu.');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      showError(context, 'The clipboard is empty.');
      return;
    }
    _json.text = text;
    _reparse();
  }

  /// The dishes actually about to be written, and why the rest are not.
  ({List<MenuDraft> dishes, List<String> warnings}) _pending(
    RaterSnapshot snapshot,
  ) {
    final target = _targetId;
    if (target == null) {
      return (dishes: _parsed.dishes, warnings: const <String>[]);
    }
    return withoutExisting(_parsed, snapshot.menuOf(target));
  }

  Future<void> _import(List<MenuDraft> dishes, RaterSnapshot snapshot) async {
    setState(() => _importing = true);
    final name = cleanName(_name.text);
    // Named, not "the menu": the toast is the only confirmation there is, and
    // it should say which place just grew a menu.
    final where = snapshot.restaurantById(_targetId ?? '')?.name ?? name;
    await widget.repository.importMenu(
      restaurantName: name,
      dishes: dishes,
      restaurantNote: cleanName(_note.text).isEmpty
          ? null
          : cleanName(_note.text),
      intoRestaurantId: _targetId,
    );
    if (!mounted) return;
    setState(() => _importing = false);
    showToast(context, '${dishCount(dishes.length)} added to $where.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.repository.snapshot();
    final pending = _pending(snapshot);
    // A new restaurant needs somewhere for the dishes to hang: with no name
    // there is nothing to call it, and the JSON did not supply one either.
    final needsName = _targetId == null && cleanName(_name.text).isEmpty;
    final canImport =
        !_importing &&
        _parsed.isImportable &&
        pending.dishes.isNotEmpty &&
        !needsName;

    return Scaffold(
      appBar: AppBar(title: const Text('Import menu')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const SectionHeader('1. Ask Claude'),
          const Text(
            'Photograph the menu, then send the photos to Claude with this '
            'prompt. Paste what comes back below.',
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => unawaited(_copyPrompt()),
            icon: const Icon(Icons.copy_all),
            label: const Text('Copy prompt'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('2. Paste the JSON'),
          TextField(
            controller: _json,
            maxLines: 6,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: '{"restaurant": ..., "dishes": [...]}',
            ),
            onChanged: (_) => _reparse(),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => unawaited(_paste()),
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from clipboard'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('3. Where it goes'),
          _target(snapshot.restaurants),
          if (_targetId == null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Restaurant'),
              onChanged: (_) => setState(() => _nameIsMine = true),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'the one by the tram stop',
              ),
              onChanged: (_) => setState(() => _nameIsMine = true),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ImportPreview(
            menu: _parsed,
            dishes: pending.dishes,
            extraWarnings: pending.warnings,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: canImport
                ? () => unawaited(_import(pending.dishes, snapshot))
                : null,
            icon: const Icon(Icons.playlist_add),
            label: Text(
              pending.dishes.isEmpty
                  ? 'Import'
                  : 'Import ${dishCount(pending.dishes.length)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _target(List<Restaurant> restaurants) =>
      DropdownButtonFormField<String?>(
        initialValue: _targetId,
        decoration: const InputDecoration(labelText: 'Add to'),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(child: Text('A new restaurant')),
          for (final restaurant in restaurants)
            DropdownMenuItem<String?>(
              value: restaurant.id,
              child: Text(restaurant.name),
            ),
        ],
        onChanged: (value) => setState(() => _targetId = value),
      );
}
