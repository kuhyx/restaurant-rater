/// Scoring one dish: smak, zapach, estetyka, plus the optional extras.
library;

import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/logic/scores.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/money.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';
import 'package:restaurant_rater/ui/rating/macros_fields.dart';
import 'package:restaurant_rater/ui/rating/photo_field.dart';
import 'package:restaurant_rater/ui/rating/score_slider.dart';

/// Records a tasting of [item].
class RatingScreen extends StatefulWidget {
  /// Creates the rating screen.
  const RatingScreen({
    required this.repository,
    required this.photos,
    required this.item,
    this.pickPhoto = defaultPickPhoto,
    super.key,
  });

  /// The data.
  final RaterRepository repository;

  /// On-device photo storage.
  final PhotoStore photos;

  /// The dish being rated.
  final MenuItem item;

  /// How a photo is obtained. Injected in tests.
  final PickPhoto pickPhoto;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  /// Minted up front, before the camera can be reached, so the photo file is
  /// written under its final name and never needs renaming at save time.
  late final String _tastingId = widget.repository.newTastingId();

  late final TextEditingController _note = TextEditingController();
  late final TextEditingController _price = TextEditingController(
    text: switch (widget.item.priceGrosz) {
      final int grosz => formatPln(grosz).replaceAll(' zł', ''),
      null => '',
    },
  );
  final TextEditingController _kcal = TextEditingController();
  final TextEditingController _protein = TextEditingController();
  final TextEditingController _fat = TextEditingController();
  final TextEditingController _carbs = TextEditingController();

  int _taste = 5;
  int _smell = 5;
  int _looks = 5;
  String? _photoName;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _note,
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

  double get _overall => (_taste + _smell + _looks) / 3;

  Future<void> _attach(File picked) async {
    // Copied at once rather than at save: image_picker hands back a path in
    // the OS cache directory, which Android may purge between the shutter and
    // the Save button.
    final name = await widget.photos.save(picked, _tastingId);
    if (!mounted) return;
    setState(() => _photoName = name);
  }

  Future<void> _clearPhoto() async {
    final name = _photoName;
    if (name != null) await widget.photos.remove(name);
    if (!mounted) return;
    setState(() => _photoName = null);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final note = _note.text.trim();
    await widget.repository.saveTasting(
      Tasting(
        id: _tastingId,
        menuItemId: widget.item.id,
        restaurantId: widget.item.restaurantId,
        eatenAt: DateTime.now().toUtc(),
        taste: _taste,
        smell: _smell,
        looks: _looks,
        macros: MacrosFields.read(
          kcal: _kcal,
          protein: _protein,
          fat: _fat,
          carbs: _carbs,
        ),
        photoName: _photoName,
        note: note.isEmpty ? null : note,
        priceGrosz: parsePln(_price.text),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.item.name),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Center(child: ScoreChip(score: _overall)),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        const SectionHeader('Scores'),
        ScoreSlider(
          label: 'Taste (smak)',
          value: _taste,
          onChanged: (value) => setState(() => _taste = value),
        ),
        ScoreSlider(
          label: 'Smell (zapach)',
          value: _smell,
          onChanged: (value) => setState(() => _smell = value),
        ),
        ScoreSlider(
          label: 'Looks (estetyka)',
          value: _looks,
          onChanged: (value) => setState(() => _looks = value),
        ),
        Center(
          child: Text(
            'Overall ${formatScore(_overall)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader('Photo'),
        PhotoField(
          photos: widget.photos,
          photoName: _photoName,
          pickPhoto: widget.pickPhoto,
          onPicked: (file) => unawaited(_attach(file)),
          onCleared: () => unawaited(_clearPhoto()),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader('Macros'),
        MacrosFields(
          kcal: _kcal,
          protein: _protein,
          fat: _fat,
          carbs: _carbs,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader('Notes'),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'too salty, portion tiny, would order again',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Paid',
            suffixText: 'zł',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _saving ? null : () => unawaited(_save()),
          icon: const Icon(Icons.check),
          label: const Text('Save rating'),
        ),
      ],
    ),
  );
}
