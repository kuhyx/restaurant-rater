/// The widget tree's root, and the startup sequence behind it.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/sync/sync_bootstrap.dart';
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/ui/restaurants/restaurants_screen.dart';

/// Builds everything the app needs, then runs it.
///
/// Split from `main()` so it is ordinary testable code: a Dart entry point is
/// never invoked under `flutter_test`, so anything left in `main` is
/// uncoverable by construction.
Future<void> runRater() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await openSyncedStore();
  runApp(
    RaterApp(
      repository: store.repository,
      photos: store.photos,
      sync: store.sync,
    ),
  );
}

/// The app root.
class RaterApp extends StatelessWidget {
  /// Creates the root over an already-built [repository].
  ///
  /// Everything is injected rather than looked up, so a widget test builds the
  /// whole tree against fakes with no plugins, no files and no network.
  const RaterApp({
    required this.repository,
    required this.photos,
    required this.sync,
    super.key,
  });

  /// The data.
  final RaterRepository repository;

  /// On-device photo storage.
  final PhotoStore photos;

  /// Runs one sync tick.
  final Future<SyncOutcome> Function() sync;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Restaurant Rater',
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    home: RestaurantsScreen(
      repository: repository,
      photos: photos,
      sync: sync,
    ),
  );
}
