/// Building a screen under the real theme, against fakes.
library;

import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:restaurant_rater/photos/photo_store.dart';

/// A photo store over a fresh temp directory, cleaned up by the caller.
PhotoStore tempPhotoStore() {
  final root = Directory.systemTemp.createTempSync('rater-widget');
  return PhotoStore(Directory(p.join(root.path, kPhotoDirName)));
}

/// Pumps [child] inside a MaterialApp using the shared theme.
///
/// The real theme rather than a bare one, because several widgets read colours
/// off `Theme.of(context).colorScheme` and would throw against Flutter's
/// default in ways that never happen in the app.
Future<void> pumpScreen(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(theme: buildLightTheme(), home: child),
  );
  await tester.pump();
}

/// A 1x1 transparent PNG: enough for `Image.file` to decode in a test.
const List<int> onePixelPng = <int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, //
  0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, //
  13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
];
