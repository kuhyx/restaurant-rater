/// Reading a pasted menu, and every way one can be odd.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/menu_import.dart';

void main() {
  group('parseMenuImport', () {
    test('reads a restaurant and its dishes, in order', () {
      final menu = parseMenuImport('''
{
  "restaurant": {"name": "Pho Bar", "note": "Krupnicza 12"},
  "dishes": [
    {"name": "tom kha", "price": "24 zł", "kcal": 380},
    {"name": "pad thai", "price": "38,50"}
  ]
}
''');

      expect(menu.error, isNull);
      expect(menu.isImportable, isTrue);
      expect(menu.restaurantName, 'Pho Bar');
      expect(menu.restaurantNote, 'Krupnicza 12');
      expect(menu.warnings, isEmpty);
      expect(
        menu.dishes.map((d) => d.name).toList(),
        <String>['tom kha', 'pad thai'],
      );
      expect(menu.dishes.first.priceGrosz, 2400);
      expect(menu.dishes.first.macros.kcal, 380);
      expect(menu.dishes.last.priceGrosz, 3850);
      expect(menu.dishes.last.macros.isEmpty, isTrue);
    });

    test('survives the markdown fence a model adds anyway', () {
      final menu = parseMenuImport(
        '```json\n{"dishes": [{"name": "zupa"}]}\n```',
      );

      expect(menu.error, isNull);
      expect(menu.dishes.single.name, 'zupa');
    });

    test('a fence with no closing backticks still parses', () {
      final menu = parseMenuImport('```\n{"dishes": [{"name": "zupa"}]}');

      expect(menu.dishes.single.name, 'zupa');
    });

    test('a lone fence line is left alone rather than emptied', () {
      expect(parseMenuImport('```json').error, isNotNull);
    });

    test('blank input is not an error worth shouting about', () {
      expect(parseMenuImport('   ').error, 'Nothing pasted yet.');
    });

    test('malformed JSON says so', () {
      expect(parseMenuImport('{oops').error, startsWith('Not valid JSON'));
    });

    test('a non-object top level is rejected', () {
      expect(
        parseMenuImport('[1, 2]').error,
        'Expected a JSON object at the top level.',
      );
    });

    test('a missing dishes list is rejected', () {
      expect(
        parseMenuImport('{"restaurant": {"name": "x"}}').error,
        'Expected a "dishes" list.',
      );
    });

    test('dishes that are not objects are dropped with a warning', () {
      final menu = parseMenuImport('{"dishes": ["zupa", {"name": "pad"}]}');

      expect(menu.dishes.single.name, 'pad');
      expect(menu.warnings.single, 'Dish 1 is not an object — skipped.');
    });

    test('a nameless dish is dropped with a warning', () {
      final menu = parseMenuImport(
        '{"dishes": [{"price": "24"}, {"name": "  "}, {"name": "pad"}]}',
      );

      expect(menu.dishes.single.name, 'pad');
      expect(menu.warnings, <String>[
        'Dish 1 has no name — skipped.',
        'Dish 2 has no name — skipped.',
      ]);
    });

    test('the same dish listed twice is kept once', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "Zupa"}, {"name": "zupa"}]}',
      );

      expect(menu.dishes.single.name, 'Zupa');
      expect(menu.warnings.single, '"zupa" is listed twice — kept once.');
    });

    test('no readable dish at all is an error, warnings kept', () {
      final menu = parseMenuImport('{"dishes": [{"name": ""}]}');

      expect(menu.error, 'No dishes found.');
      expect(menu.isImportable, isFalse);
      expect(menu.warnings, isNotEmpty);
    });

    test('a name is collapsed to the string that will be stored', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "  tom   kha \\n z kurczakiem "}]}',
      );

      expect(menu.dishes.single.name, 'tom kha z kurczakiem');
    });

    test('a restaurant block that is not an object leaves the name unset', () {
      final menu = parseMenuImport(
        '{"restaurant": "Pho Bar", "dishes": [{"name": "zupa"}]}',
      );

      expect(menu.restaurantName, isNull);
      expect(menu.restaurantNote, isNull);
    });

    test('a restaurant block with blank fields leaves them unset', () {
      final menu = parseMenuImport(
        '{"restaurant": {"name": " ", "note": ""}, '
        '"dishes": [{"name": "zupa"}]}',
      );

      expect(menu.restaurantName, isNull);
      expect(menu.restaurantNote, isNull);
    });
  });
}
