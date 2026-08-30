/// The two dialogs, including the keyboard's own submit action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/ui/menu/menu_item_editor.dart';
import 'package:restaurant_rater/ui/restaurants/restaurant_editor.dart';

import '../support/builders.dart';
import '../support/pump.dart';

void main() {
  /// Opens [open] from a button, so a Navigator is in scope.
  Future<T?> viaButton<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext) open,
  ) async {
    T? result;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await open(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  group('restaurant editor', () {
    testWidgets('the keyboard submit saves, same as the button', (
      tester,
    ) async {
      // Pressing Enter is how this actually gets used one-handed at a table;
      // it must not be a dead key.
      await viaButton(tester, editRestaurantDialog);
      await tester.enterText(find.byType(TextField).at(0), 'Tuk Tuk');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('submitting from the note field also saves', (tester) async {
      await viaButton(tester, editRestaurantDialog);
      await tester.enterText(find.byType(TextField).at(0), 'Tuk Tuk');
      await tester.enterText(find.byType(TextField).at(1), 'ul. Koszykowa');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a blank name will not submit from the keyboard either', (
      tester,
    ) async {
      await viaButton(tester, editRestaurantDialog);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget, reason: 'still open');
    });

    testWidgets('pre-fills and re-titles when editing', (tester) async {
      await viaButton(
        tester,
        (context) => editRestaurantDialog(
          context,
          existing: aRestaurant(note: 'by the tram stop'),
        ),
      );
      expect(find.text('Edit restaurant'), findsOneWidget);
      expect(find.text('Bar Tajski'), findsOneWidget);
      expect(find.text('by the tram stop'), findsOneWidget);
    });
  });

  group('menu item editor', () {
    testWidgets('the keyboard submit saves from either field', (tester) async {
      await viaButton(tester, editMenuItemDialog);
      await tester.enterText(find.byType(TextField).at(0), 'pad thai');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('submitting from the price field saves too', (tester) async {
      await viaButton(tester, editMenuItemDialog);
      await tester.enterText(find.byType(TextField).at(0), 'pad thai');
      await tester.enterText(find.byType(TextField).at(1), '28');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a blank dish name will not submit', (tester) async {
      await viaButton(tester, editMenuItemDialog);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('pre-fills the price without its unit', (tester) async {
      await viaButton(
        tester,
        (context) => editMenuItemDialog(
          context,
          existing: aMenuItem(priceGrosz: 2450),
        ),
      );
      expect(find.text('Edit dish'), findsOneWidget);
      final price = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(price.controller!.text, '24,50');
    });

    testWidgets('leaves the price blank when the dish has none', (
      tester,
    ) async {
      await viaButton(
        tester,
        (context) =>
            editMenuItemDialog(context, existing: aMenuItem(priceGrosz: null)),
      );
      final price = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(price.controller!.text, isEmpty);
    });
  });

  group('menu item macros', () {
    testWidgets('shows what the menu claimed, whole numbers without a .0', (
      tester,
    ) async {
      await viaButton<MenuItemDraft>(
        tester,
        (context) => editMenuItemDialog(
          context,
          existing: aMenuItem(
            macros: const Macros(kcal: 380, proteinG: 21.5),
          ),
        ),
      );

      expect(find.widgetWithText(TextField, '380'), findsOneWidget);
      expect(find.widgetWithText(TextField, '21.5'), findsOneWidget);
      // Unrecorded is blank, not zero: they are different claims.
      expect(find.widgetWithText(TextField, '0'), findsNothing);
    });

    testWidgets('hands the typed macros back with the draft', (tester) async {
      final draft = await viaButton<MenuItemDraft>(
        tester,
        (context) => editMenuItemDialog(context),
      );

      expect(draft, isNull, reason: 'dismissed without typing anything');
    });

    testWidgets('saves the macros typed into the dialog', (tester) async {
      MenuItemDraft? draft;
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => draft = await editMenuItemDialog(context),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Dish'), 'zupa');
      await tester.enterText(find.widgetWithText(TextField, 'Energy'), '420');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(draft?.name, 'zupa');
      expect(draft?.macros.kcal, 420);
    });
  });
}
