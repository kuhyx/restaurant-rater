/// The four optional macronutrient inputs.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/models/macros.dart';

/// Four number fields: kcal, protein, fat, carbs. All optional.
///
/// Stateless and controller-driven, so the parent owns the text and this
/// widget never has to reconcile its own state with a rebuild.
class MacrosFields extends StatelessWidget {
  /// Creates the field group.
  const MacrosFields({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    super.key,
  });

  /// Energy, in kcal.
  final TextEditingController kcal;

  /// Protein, in grams.
  final TextEditingController protein;

  /// Fat, in grams.
  final TextEditingController fat;

  /// Carbohydrate, in grams.
  final TextEditingController carbs;

  /// Reads the four controllers into a [Macros].
  ///
  /// A blank or unparseable field becomes null — "unknown", which is a
  /// different claim from zero and is why every field is nullable.
  static Macros read({
    required TextEditingController kcal,
    required TextEditingController protein,
    required TextEditingController fat,
    required TextEditingController carbs,
  }) => Macros(
    kcal: _parse(kcal.text),
    proteinG: _parse(protein.text),
    fatG: _parse(fat.text),
    carbsG: _parse(carbs.text),
  );

  static double? _parse(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(child: _field(kcal, 'Energy', 'kcal')),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _field(protein, 'Protein', 'g')),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: <Widget>[
          Expanded(child: _field(fat, 'Fat', 'g')),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _field(carbs, 'Carbs', 'g')),
        ],
      ),
    ],
  );

  Widget _field(TextEditingController controller, String label, String unit) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: unit),
      );
}
