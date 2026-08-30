/// Turning a pasted JSON menu into dishes the repository can write.
library;

import 'dart:convert';

import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/money.dart';

/// The prompt handed to Claude alongside photographs of a menu.
///
/// It lives in the app, not in a note, so that what the model is asked to
/// produce and what [parseMenuImport] can read cannot drift apart: changing
/// one without the other is a compile-adjacent edit to the same file.
///
/// It asks for what a menu actually prints and forbids the rest. A model that
/// helpfully estimates calories produces numbers indistinguishable from
/// printed ones the moment they are stored, and there would be no way to tell
/// afterwards which was which.
const String kMenuImportPrompt = '''
These are photographs of one restaurant's menu. Transcribe them into JSON.

Reply with the JSON object and nothing else: no explanation before it, no
markdown code fence around it.

{
  "restaurant": { "name": "<the place's name>", "note": "<address, optional>" },
  "dishes": [
    { "name": "<the dish, exactly as printed>",
      "price": "<as printed, e.g. 24 zl or 38,50>",
      "kcal": 380, "proteinG": 21, "fatG": 14, "carbsG": 30 }
  ]
}

Rules:
- Keep dish names exactly as printed, in the menu's own language, with its
  own diacritics. Do not translate, expand or tidy them.
- Keep the menu's order, top to bottom, left to right across columns.
- Omit any field the menu does not print. Never estimate a price or a macro,
  and never invent a dish that is not there.
- One object for the whole menu, even when it took several photographs.
- Skip drinks unless the menu lists them among the food.
''';

/// A pasted menu, after parsing: what to import, and everything that was odd
/// about it.
///
/// Warnings rather than failures, throughout. The input is model output pasted
/// by hand at a table; one strange field must cost that field and no more,
/// because a menu rejected wholesale sends you back to typing it in.
class ImportedMenu {
  /// Creates a parse result.
  const ImportedMenu({
    required this.dishes,
    required this.warnings,
    this.restaurantName,
    this.restaurantNote,
    this.error,
  });

  /// Nothing usable, and why.
  factory ImportedMenu.failed(String error) => ImportedMenu(
    dishes: const <MenuDraft>[],
    warnings: const <String>[],
    error: error,
  );

  /// The name the JSON gave the restaurant, or null when it named none.
  final String? restaurantName;

  /// The note the JSON gave the restaurant, or null.
  final String? restaurantNote;

  /// The dishes to write, in the order they were listed.
  final List<MenuDraft> dishes;

  /// What was dropped or could not be read, one line each, in dish order.
  final List<String> warnings;

  /// Why nothing could be read at all, or null when something could.
  final String? error;

  /// Whether there is at least one dish to write.
  bool get isImportable => error == null && dishes.isNotEmpty;
}

/// Reads [text] into an [ImportedMenu].
///
/// Tolerates a ``` fence around the JSON, because that is what a model emits
/// roughly half the time however plainly [kMenuImportPrompt] asks it not to,
/// and stripping it here is cheaper than making the user do it.
ImportedMenu parseMenuImport(String text) {
  final trimmed = _stripFence(text.trim());
  if (trimmed.isEmpty) return ImportedMenu.failed('Nothing pasted yet.');

  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException catch (error) {
    return ImportedMenu.failed('Not valid JSON: ${error.message}');
  }

  if (decoded is! Map<String, dynamic>) {
    return ImportedMenu.failed('Expected a JSON object at the top level.');
  }

  final rawDishes = decoded['dishes'];
  if (rawDishes is! List) {
    return ImportedMenu.failed('Expected a "dishes" list.');
  }

  final warnings = <String>[];
  final dishes = <MenuDraft>[];
  final seen = <String>{};

  for (var index = 0; index < rawDishes.length; index++) {
    final raw = rawDishes[index];
    final where = 'Dish ${index + 1}';
    if (raw is! Map<String, dynamic>) {
      warnings.add('$where is not an object — skipped.');
      continue;
    }
    final name = _cleanWhitespace('${raw['name'] ?? ''}');
    if (name.isEmpty) {
      warnings.add('$where has no name — skipped.');
      continue;
    }
    if (!seen.add(name.toLowerCase())) {
      warnings.add('"$name" is listed twice — kept once.');
      continue;
    }
    dishes.add((
      name: name,
      priceGrosz: _price(raw, name, warnings),
      macros: _macros(raw, name, warnings),
    ));
  }

  if (dishes.isEmpty) {
    return ImportedMenu(
      dishes: dishes,
      warnings: warnings,
      error: 'No dishes found.',
    );
  }

  final restaurant = decoded['restaurant'];
  final name = restaurant is Map<String, dynamic>
      ? _cleanWhitespace('${restaurant['name'] ?? ''}')
      : '';
  final note = restaurant is Map<String, dynamic>
      ? _cleanWhitespace('${restaurant['note'] ?? ''}')
      : '';

  return ImportedMenu(
    restaurantName: name.isEmpty ? null : name,
    restaurantNote: note.isEmpty ? null : note,
    dishes: dishes,
    warnings: warnings,
  );
}

/// The dishes of [menu] that are not already on [existing], and a warning for
/// each one that is.
///
/// Import is additive: a dish already on the menu is left exactly as it is,
/// price, macros, skip and all. Re-importing a menu after adding two dishes to
/// it should add two dishes, not overwrite the ratings attached to the rest.
({List<MenuDraft> dishes, List<String> warnings}) withoutExisting(
  ImportedMenu menu,
  List<MenuItem> existing,
) {
  final known = existing.map((item) => item.name.toLowerCase()).toSet();
  final fresh = <MenuDraft>[];
  final warnings = <String>[];
  for (final dish in menu.dishes) {
    if (known.contains(dish.name.toLowerCase())) {
      warnings.add('"${dish.name}" is already on this menu — skipped.');
    } else {
      fresh.add(dish);
    }
  }
  return (dishes: fresh, warnings: warnings);
}

/// Strips a leading ```` ```json ```` fence and its closing ``` ````, if any.
String _stripFence(String text) {
  if (!text.startsWith('```')) return text;
  final firstBreak = text.indexOf('\n');
  if (firstBreak < 0) return text;
  final body = text.substring(firstBreak + 1);
  final close = body.lastIndexOf('```');
  return (close < 0 ? body : body.substring(0, close)).trim();
}

/// Reads a dish's price, preferring an explicit grosz integer.
///
/// `priceGrosz` wins because it is unambiguous. `price` is accepted as a
/// string *and* as a number: models emit `"price": 24.5` however firmly the
/// prompt asks for the printed form, and dropping every price on that account
/// would look exactly like a broken importer.
int? _price(Map<String, dynamic> raw, String name, List<String> warnings) {
  final grosz = raw['priceGrosz'];
  if (grosz is int) return grosz;

  final price = raw['price'];
  if (price == null) return null;
  if (price is num) return (price * 100).round();

  final parsed = parsePln('$price');
  if (parsed == null) {
    warnings.add('"$name" has an unreadable price ($price) — left blank.');
  }
  return parsed;
}

/// Reads the four optional macros, warning once per unreadable component.
Macros _macros(Map<String, dynamic> raw, String name, List<String> warnings) =>
    Macros(
      kcal: _macro(raw, 'kcal', name, warnings),
      proteinG: _macro(raw, 'proteinG', name, warnings),
      fatG: _macro(raw, 'fatG', name, warnings),
      carbsG: _macro(raw, 'carbsG', name, warnings),
    );

double? _macro(
  Map<String, dynamic> raw,
  String field,
  String name,
  List<String> warnings,
) {
  final value = raw[field];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final parsed = double.tryParse('$value'.replaceAll(',', '.'));
  if (parsed == null) {
    warnings.add('"$name" has an unreadable $field ($value) — left blank.');
  }
  return parsed;
}

/// Trims the ends and collapses interior runs of whitespace.
///
/// The same normalisation `cleanName` applies at the repository boundary, done
/// here too so that the preview shows the string that will actually be
/// written rather than one that still has the menu's line breaks in it.
String _cleanWhitespace(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');
