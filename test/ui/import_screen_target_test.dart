/// Choosing where an imported menu goes, and what that changes.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/menu_import.dart';
import 'package:restaurant_rater/ui/import/import_screen.dart';

import '../support/builders.dart';
import '../support/fake_rater_repository.dart';
import '../support/pump.dart';

void main() {
  late FakeRaterRepository repository;
  String? copied;
  String? clipboard;

  setUp(() {
    repository = FakeRaterRepository();
    copied = null;
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              copied = (call.arguments as Map)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return clipboard == null
                  ? null
                  : <String, Object?>{'text': clipboard};
            default:
              return null;
          }
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await repository.dispose();
  });

  /// Pushes the screen the way the app does: onto a route, on a surface tall
  /// enough to hold it.
  ///
  /// Pushed rather than pumped as `home`, because importing pops — and popping
  /// the only route leaves an empty tree with no ScaffoldMessenger, so the
  /// confirmation toast would be unassertable for a reason the app never has.
  ///
  /// The tall surface is for the same class of reason: the default 800px test
  /// window puts the preview and the Import button below the fold, and a
  /// ListView does not build what is off-screen.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: Text('restaurants')),
      ),
    );
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ImportScreen(repository: repository),
            ),
          ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> paste(WidgetTester tester, String json) async {
    await tester.enterText(find.byType(TextField).first, json);
    await tester.pumpAndSettle();
  }

  const twoDishes =
      '{"restaurant": {"name": "Pho Bar", "note": "Krupnicza 12"}, '
      '"dishes": [{"name": "tom kha", "price": "24"}, '
      '{"name": "pad thai", "kcal": 512}]}';

  testWidgets('appends to an existing restaurant, skipping what it has', (
    tester,
  ) async {
    repository.restaurants.add(aRestaurant(name: 'Pho Bar'));
    repository.menuItems.add(aMenuItem(name: 'tom kha'));
    await open(tester);
    await paste(tester, twoDishes);

    await tester.tap(find.text('A new restaurant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pho Bar').last);
    await tester.pumpAndSettle();

    expect(
      find.text('"tom kha" is already on this menu — skipped.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Import 1 dish'));
    await tester.pumpAndSettle();

    expect(repository.restaurants, hasLength(1));
    expect(
      repository.menuItems.map((item) => item.name).toList(),
      <String>['tom kha', 'pad thai'],
    );
    expect(find.text('1 dish added to Pho Bar.'), findsOneWidget);
  });

  testWidgets('a note typed by hand survives the next keystroke', (
    tester,
  ) async {
    await open(tester);
    await paste(tester, twoDishes);

    await tester.enterText(
      find.widgetWithText(TextField, 'Krupnicza 12'),
      'by the tram stop',
    );
    await tester.pumpAndSettle();
    await paste(tester, twoDishes);

    expect(find.widgetWithText(TextField, 'by the tram stop'), findsOneWidget);
  });

  testWidgets('will not import with no name for a new restaurant', (
    tester,
  ) async {
    await open(tester);
    await paste(tester, '{"dishes": [{"name": "zupa"}]}');

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('will not import when every dish is already there', (
    tester,
  ) async {
    repository.restaurants.add(aRestaurant(name: 'Pho Bar'));
    repository.menuItems
      ..add(aMenuItem(id: 'm1', name: 'tom kha'))
      ..add(aMenuItem(id: 'm2', name: 'pad thai'));
    await open(tester);
    await paste(tester, twoDishes);

    await tester.tap(find.text('A new restaurant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pho Bar').last);
    await tester.pumpAndSettle();

    expect(find.text('Every dish is already on this menu.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows the parse error rather than an empty preview', (
    tester,
  ) async {
    await open(tester);
    await paste(tester, '{oops');

    expect(find.textContaining('Not valid JSON'), findsOneWidget);
  });
}
