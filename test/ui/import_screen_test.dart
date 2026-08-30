/// Pasting a menu in: the preview, the target, and what actually gets written.
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

  testWidgets('copies the prompt for Claude', (tester) async {
    await open(tester);

    await tester.tap(find.text('Copy prompt'));
    await tester.pumpAndSettle();

    expect(copied, kMenuImportPrompt);
  });

  testWidgets('pastes the clipboard into the field', (tester) async {
    clipboard = twoDishes;
    await open(tester);

    await tester.tap(find.text('Paste from clipboard'));
    await tester.pumpAndSettle();

    expect(find.text('tom kha'), findsOneWidget);
    expect(find.text('pad thai'), findsOneWidget);
  });

  testWidgets('says so when the clipboard is empty', (tester) async {
    clipboard = '   ';
    await open(tester);

    await tester.tap(find.text('Paste from clipboard'));
    await tester.pumpAndSettle();

    expect(find.text('The clipboard is empty.'), findsOneWidget);
  });

  testWidgets('an absent clipboard is the same as an empty one', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Paste from clipboard'));
    await tester.pumpAndSettle();

    expect(find.text('The clipboard is empty.'), findsOneWidget);
  });

  testWidgets('previews the dishes and fills the name from the JSON', (
    tester,
  ) async {
    await open(tester);
    await paste(tester, twoDishes);

    expect(find.text('Preview — 2 dishes'), findsOneWidget);
    expect(find.text('24 zł'), findsOneWidget);
    expect(find.text('512 kcal'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Pho Bar'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Krupnicza 12'), findsOneWidget);
  });

  testWidgets('writes a new restaurant and its dishes, in order', (
    tester,
  ) async {
    await open(tester);
    await paste(tester, twoDishes);

    await tester.tap(find.text('Import 2 dishes'));
    await tester.pumpAndSettle();

    expect(repository.restaurants.single.name, 'Pho Bar');
    expect(repository.restaurants.single.note, 'Krupnicza 12');
    expect(
      repository.menuItems.map((item) => item.name).toList(),
      <String>['tom kha', 'pad thai'],
    );
    expect(repository.menuItems.first.priceGrosz, 2400);
    expect(repository.menuItems.last.macros.kcal, 512);
    expect(find.text('2 dishes added to Pho Bar.'), findsOneWidget);
  });

  testWidgets('a name typed by hand survives the next keystroke', (
    tester,
  ) async {
    await open(tester);
    await paste(tester, twoDishes);

    await tester.enterText(
      find.widgetWithText(TextField, 'Pho Bar'),
      'Pho Bar II',
    );
    await tester.pumpAndSettle();
    // Re-parsing must not stamp the JSON's name back over the correction.
    await paste(tester, twoDishes);

    expect(find.widgetWithText(TextField, 'Pho Bar II'), findsOneWidget);
  });
}
