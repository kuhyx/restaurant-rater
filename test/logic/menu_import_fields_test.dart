/// Reading one dish's price and macros out of pasted JSON.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/menu_import.dart';
import 'package:restaurant_rater/models/menu_item.dart';

import '../support/builders.dart';

void main() {
  group('prices', () {
    test('priceGrosz wins outright over a printed price', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "zupa", "priceGrosz": 2450, "price": "99"}]}',
      );

      expect(menu.dishes.single.priceGrosz, 2450);
    });

    test('a numeric price is taken as złoty, not dropped', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "a", "price": 24.5}, '
        '{"name": "b", "price": 24}]}',
      );

      expect(menu.dishes.first.priceGrosz, 2450);
      expect(menu.dishes.last.priceGrosz, 2400);
      expect(menu.warnings, isEmpty);
    });

    test('an unreadable price costs the price and nothing else', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "zupa", "price": "market rate"}]}',
      );

      expect(menu.dishes.single.name, 'zupa');
      expect(menu.dishes.single.priceGrosz, isNull);
      expect(
        menu.warnings.single,
        '"zupa" has an unreadable price (market rate) — left blank.',
      );
    });

    test('an absent price is not a warning', () {
      final menu = parseMenuImport('{"dishes": [{"name": "zupa"}]}');

      expect(menu.dishes.single.priceGrosz, isNull);
      expect(menu.warnings, isEmpty);
    });
  });

  group('macros', () {
    test('all four are read', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "z", "kcal": 380, "proteinG": 21.5, '
        '"fatG": 14, "carbsG": 30}]}',
      );
      final macros = menu.dishes.single.macros;

      expect(macros.kcal, 380);
      expect(macros.proteinG, 21.5);
      expect(macros.fatG, 14);
      expect(macros.carbsG, 30);
    });

    test('a numeric string is accepted, comma included', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "z", "kcal": "380", "proteinG": "21,5"}]}',
      );

      expect(menu.dishes.single.macros.kcal, 380);
      expect(menu.dishes.single.macros.proteinG, 21.5);
      expect(menu.warnings, isEmpty);
    });

    test('an unreadable macro costs that macro alone', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "z", "kcal": "lots", "proteinG": 21}]}',
      );

      expect(menu.dishes.single.macros.kcal, isNull);
      expect(menu.dishes.single.macros.proteinG, 21);
      expect(
        menu.warnings.single,
        '"z" has an unreadable kcal (lots) — left blank.',
      );
    });
  });

  group('withoutExisting', () {
    test('drops the dishes already on the menu, and says which', () {
      final menu = parseMenuImport(
        '{"dishes": [{"name": "Tom Kha"}, {"name": "pad thai"}]}',
      );

      final pending = withoutExisting(menu, <MenuItem>[
        aMenuItem(name: 'tom kha'),
      ]);

      expect(pending.dishes.single.name, 'pad thai');
      expect(
        pending.warnings.single,
        '"Tom Kha" is already on this menu — skipped.',
      );
    });

    test('an empty menu takes everything', () {
      final menu = parseMenuImport('{"dishes": [{"name": "zupa"}]}');

      final pending = withoutExisting(menu, const <MenuItem>[]);

      expect(pending.dishes, hasLength(1));
      expect(pending.warnings, isEmpty);
    });
  });

  test('the prompt names every field the parser reads', () {
    for (final field in <String>[
      'restaurant',
      'dishes',
      'name',
      'price',
      'kcal',
      'proteinG',
      'fatG',
      'carbsG',
    ]) {
      expect(kMenuImportPrompt, contains(field));
    }
  });
}
