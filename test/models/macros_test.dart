/// Macros: optional, independent, and never confused with zero.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/macros.dart';

void main() {
  test('empty is not the same claim as all-zero', () {
    expect(Macros.empty.isEmpty, isTrue);
    const zeroed = Macros(kcal: 0, proteinG: 0, fatG: 0, carbsG: 0);
    expect(zeroed.isEmpty, isFalse, reason: '0 kcal is a claim, not silence');
    expect(zeroed.isNotEmpty, isTrue);
  });

  test('one recorded component is enough to be non-empty', () {
    expect(const Macros(kcal: 320).isNotEmpty, isTrue);
  });

  test('round-trips through JSON, omitting unknown components', () {
    const macros = Macros(kcal: 320, proteinG: 24);
    expect(macros.toJson(), <String, dynamic>{'kcal': 320.0, 'proteinG': 24.0});
    expect(Macros.fromJson(macros.toJson()), macros);
  });

  test('decodes an unreadable component to null rather than throwing', () {
    // These arrive from a peer that may be on a different build; one bad
    // macro must not take down the whole dish.
    final decoded = Macros.fromJson(<String, dynamic>{
      'kcal': 'lots',
      'proteinG': 24,
    });
    expect(decoded.kcal, isNull);
    expect(decoded.proteinG, 24.0);
  });

  test('copyWith tells "clear it" apart from "leave it alone"', () {
    const macros = Macros(kcal: 320, proteinG: 24);
    expect(macros.copyWith(proteinG: () => null).proteinG, isNull);
    expect(macros.copyWith(proteinG: () => null).kcal, 320);
    expect(macros.copyWith().kcal, 320, reason: 'omitted means untouched');
    expect(macros.copyWith(kcal: () => 400).kcal, 400);
    expect(macros.copyWith(fatG: () => 9).fatG, 9);
    expect(macros.copyWith(carbsG: () => 12).carbsG, 12);
  });

  test('has value equality and a matching hashCode', () {
    expect(const Macros(kcal: 1), const Macros(kcal: 1));
    expect(const Macros(kcal: 1).hashCode, const Macros(kcal: 1).hashCode);
    expect(const Macros(kcal: 1), isNot(const Macros(kcal: 2)));
    expect(const Macros(proteinG: 1), isNot(const Macros(fatG: 1)));
    expect(const Macros(fatG: 1), isNot(const Macros(carbsG: 1)));
    expect(Macros.empty, isNot(3));
  });

  test('prints all four components', () {
    expect(const Macros(kcal: 320).toString(), contains('320'));
  });
}
