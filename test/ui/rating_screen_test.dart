/// Scoring a dish: the sliders, the photo seam, macros and the save.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/ui/rating/photo_field.dart';
import 'package:restaurant_rater/ui/rating/rating_screen.dart';
import 'package:restaurant_rater/ui/rating/score_slider.dart';

import '../support/builders.dart';
import '../support/fake_rater_repository.dart';
import '../support/pump.dart';

void main() {
  late FakeRaterRepository repository;
  late PhotoStore photos;

  setUp(() {
    repository = FakeRaterRepository(
      restaurants: <Restaurant>[aRestaurant()],
      menuItems: <MenuItem>[aMenuItem()],
    );
    photos = tempPhotoStore();
  });

  tearDown(() => repository.dispose());

  Future<void> open(
    WidgetTester tester, {
    PickPhoto? pickPhoto,
    MenuItem? item,
  }) {
    // A tall surface so the whole form is built at once. The ListView is lazy,
    // so on the default 800px viewport the note and price fields do not exist
    // in the tree at all and finding them throws rather than failing.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return pumpScreen(
      tester,
      RatingScreen(
        repository: repository,
        photos: photos,
        item: item ?? aMenuItem(),
        pickPhoto: pickPhoto ?? (_) async => null,
      ),
    );
  }

  /// Drags a slider by [steps] tenths of its track.
  Future<void> nudge(WidgetTester tester, String label, int steps) async {
    final slider = find.descendant(
      of: find.widgetWithText(ScoreSlider, label),
      matching: find.byType(Slider),
    );
    final box = tester.getSize(slider);
    await tester.drag(slider, Offset(box.width / 10 * steps, 0));
    await tester.pump();
  }

  /// The note field, found by its hint rather than a fragile index.
  Finder noteField() => find.widgetWithText(
    TextField,
    'too salty, portion tiny, would order again',
  );

  /// Taps Save and lets the pop settle.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save rating'));
    await tester.pump();
    await tester.pump();
  }

  /// Taps [label] and lets the real file IO behind it finish.
  ///
  /// The tap has to happen INSIDE runAsync. Copying the photo in is genuine
  /// async IO, and a future created under the widget tester's fake clock never
  /// progresses -- tapping outside and only waiting inside leaves the copy
  /// permanently pending, so the button appears to do nothing.
  ///
  /// Manual pumps afterwards rather than pumpAndSettle, which hangs once a
  /// runAsync gap is in the mix.
  Future<void> tapWithIo(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();
  }

  testWidgets('starts at the middle of every axis', (tester) async {
    await open(tester);
    expect(find.text('Overall 5,0'), findsOneWidget);
    expect(find.text('Taste (smak)'), findsOneWidget);
    expect(find.text('Smell (zapach)'), findsOneWidget);
    expect(find.text('Looks (estetyka)'), findsOneWidget);
  });

  testWidgets('recomputes the overall as an axis moves', (tester) async {
    await open(tester);
    await nudge(tester, 'Taste (smak)', 2);
    expect(find.text('Overall 5,7'), findsOneWidget);
  });

  testWidgets('every axis moves independently', (tester) async {
    await open(tester);
    await nudge(tester, 'Smell (zapach)', 2);
    await nudge(tester, 'Looks (estetyka)', -2);
    await save(tester);

    final saved = repository.tastings.single;
    expect(saved.taste, 5, reason: 'untouched');
    expect(saved.smell, 7);
    expect(saved.looks, 3);
  });

  testWidgets('saves the scores, the note and the price paid', (tester) async {
    await open(tester);
    await nudge(tester, 'Taste (smak)', 2);
    await tester.enterText(noteField(), 'too salty');
    await tester.pump();

    await save(tester);

    expect(repository.calls, contains('saveTasting:m1'));
    final saved = repository.tastings.single;
    expect(saved.taste, 7);
    expect(saved.smell, 5);
    expect(saved.looks, 5);
    expect(saved.note, 'too salty');
    expect(saved.priceGrosz, 2400, reason: 'pre-filled from the menu price');
    expect(saved.photoName, isNull);
  });

  testWidgets('records macros, leaving unfilled ones unknown', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).at(0), '320');
    await tester.enterText(find.byType(TextField).at(1), '24,5');
    await tester.pump();

    await save(tester);

    final macros = repository.tastings.single.macros;
    expect(macros.kcal, 320);
    expect(macros.proteinG, 24.5, reason: 'a comma is a decimal point here');
    expect(macros.fatG, isNull, reason: 'unknown, which is not zero');
  });

  testWidgets('an empty note is stored as absent, not as ""', (tester) async {
    await open(tester);
    await tester.enterText(noteField(), '   ');
    await tester.pump();
    await save(tester);
    expect(repository.tastings.single.note, isNull);
  });

  group('photo', () {
    testWidgets('a cancelled picker changes nothing', (tester) async {
      await open(tester, pickPhoto: (_) async => null);
      await tester.tap(find.text('Camera'));
      await tester.pump();
      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('a taken photo is copied in and named after the tasting', (
      tester,
    ) async {
      final source = File(p.join(photos.directory.parent.path, 'cache.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(onePixelPng);

      await open(tester, pickPhoto: (_) async => XFile(source.path));
      await tapWithIo(tester, 'Gallery');

      expect(find.text('Remove'), findsOneWidget);
      await save(tester);

      final saved = repository.tastings.single;
      expect(saved.photoName, 'minted-0.jpg');
      expect(photos.exists(saved.photoName!), isTrue);
      expect(source.existsSync(), isTrue, reason: 'copied, never moved');
    });

    testWidgets('removing a photo deletes the file too', (tester) async {
      final source = File(p.join(photos.directory.parent.path, 'cache.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(onePixelPng);

      await open(tester, pickPhoto: (_) async => XFile(source.path));
      await tapWithIo(tester, 'Camera');
      await tapWithIo(tester, 'Remove');

      expect(find.text('Remove'), findsNothing);
      expect(photos.exists('minted-0.jpg'), isFalse);
    });
  });

  testWidgets("pre-fills the macros the menu claimed, and lets them be "
      'overwritten', (tester) async {
    // The same treatment the price already gets: a starting point to correct,
    // not a reading. Saving copies whatever is in the field at that moment.
    await open(tester, item: aMenuItem(macros: const Macros(kcal: 380)));

    expect(find.widgetWithText(TextField, '380'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '380'), '410');
    await tester.tap(find.text('Save rating'));
    await tester.pumpAndSettle();

    expect(repository.tastings.single.macros.kcal, 410);
  });
}
