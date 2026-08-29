/// The two shared widgets every list leans on.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/ui/common/photo_thumb.dart';
import 'package:restaurant_rater/ui/common/score_chip.dart';

import '../support/pump.dart';

void main() {
  group('ScoreChip', () {
    test('colours by verdict, in three bands rather than a gradient', () {
      expect(ScoreChip.colorFor(9), AppPalette.success);
      expect(ScoreChip.colorFor(7), AppPalette.success);
      expect(ScoreChip.colorFor(5), AppPalette.warning);
      expect(ScoreChip.colorFor(4), AppPalette.warning);
      expect(ScoreChip.colorFor(3.9), AppPalette.danger);
    });

    testWidgets('renders the number, and a caption when given one', (
      tester,
    ) async {
      await pumpScreen(tester, const ScoreChip(score: 5.67));
      expect(find.text('5,7'), findsOneWidget);

      await pumpScreen(tester, const ScoreChip(score: 3, label: 'smak'));
      expect(find.text('smak 3,0'), findsOneWidget);
    });
  });

  group('PhotoThumb', () {
    testWidgets('renders nothing when no photo was taken', (tester) async {
      final photos = tempPhotoStore();
      await pumpScreen(tester, PhotoThumb(photos: photos, photoName: null));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('says where the photo is when the file is not here', (
      tester,
    ) async {
      // The common case for anything rated on the other phone: metadata
      // syncs, image files do not. It must not read as corruption, and it
      // must not be silent.
      final photos = tempPhotoStore();
      await pumpScreen(
        tester,
        PhotoThumb(photos: photos, photoName: 'elsewhere.jpg'),
      );
      expect(find.byTooltip('Photo is on another device'), findsOneWidget);
      expect(find.byIcon(Icons.phone_iphone), findsOneWidget);
    });

    testWidgets('renders the file when it is here', (tester) async {
      final photos = tempPhotoStore();
      photos.directory.createSync(recursive: true);
      photos.fileFor('here.jpg').writeAsBytesSync(onePixelPng);
      await pumpScreen(
        tester,
        PhotoThumb(photos: photos, photoName: 'here.jpg'),
      );
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
