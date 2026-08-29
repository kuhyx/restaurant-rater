/// Home: every restaurant, and the way in to each one's next dish.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/logic/stats.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/ui/common/rater_scope.dart';
import 'package:restaurant_rater/ui/history/history_screen.dart';
import 'package:restaurant_rater/ui/menu/menu_screen.dart';
import 'package:restaurant_rater/ui/pick/pick_screen.dart';
import 'package:restaurant_rater/ui/restaurants/restaurant_editor.dart';
import 'package:restaurant_rater/ui/restaurants/restaurant_tile.dart';
import 'package:restaurant_rater/ui/settings/settings_screen.dart';
import 'package:restaurant_rater/ui/settings/sync_actions.dart';

/// The restaurants list.
class RestaurantsScreen extends StatelessWidget {
  /// Creates the home screen.
  const RestaurantsScreen({
    required this.repository,
    required this.photos,
    required this.sync,
    this.syncProbe = probeSyncSession,
    this.syncConnect = connectSyncAccount,
    super.key,
  });

  /// The data.
  final RaterRepository repository;

  /// On-device photo storage.
  final PhotoStore photos;

  /// Runs one sync tick.
  final Future<SyncOutcome> Function() sync;

  /// Reports whether this device holds a sync session. Injected in tests.
  final SyncProbe syncProbe;

  /// Performs the interactive sign-in. Injected in tests.
  final SyncConnect syncConnect;

  Future<void> _add(BuildContext context) async {
    final draft = await editRestaurantDialog(context);
    if (draft == null) return;
    await repository.addRestaurant(name: draft.name, note: draft.note);
  }

  void _openPick(BuildContext context, Restaurant restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PickScreen(
          repository: repository,
          photos: photos,
          restaurantId: restaurant.id,
        ),
      ),
    );
  }

  void _openMenu(BuildContext context, Restaurant restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MenuScreen(
          repository: repository,
          restaurantId: restaurant.id,
        ),
      ),
    );
  }

  void _openRoute(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Restaurants'),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'History',
          onPressed: () => _openRoute(
            context,
            HistoryScreen(repository: repository, photos: photos),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () => _openRoute(
            context,
            SettingsScreen(
              repository: repository,
              sync: sync,
              syncProbe: syncProbe,
              syncConnect: syncConnect,
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _add(context),
      tooltip: 'Add restaurant',
      child: const Icon(Icons.add),
    ),
    body: RaterScope(
      repository: repository,
      builder: _body,
    ),
  );

  Widget _body(BuildContext context, RaterSnapshot snapshot) {
    if (snapshot.restaurants.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront,
        title: 'No restaurants yet',
        message: 'Add a place, then type in its menu.',
      );
    }
    return ListView.builder(
      itemCount: snapshot.restaurants.length,
      itemBuilder: (context, index) {
        final restaurant = snapshot.restaurants[index];
        return RestaurantTile(
          restaurant: restaurant,
          progress: progressOf(
            menu: snapshot.menuOf(restaurant.id),
            tastings: snapshot.tastingsOf(restaurant.id),
          ),
          onTap: () => _openPick(context, restaurant),
          onEditMenu: () => _openMenu(context, restaurant),
        );
      },
    );
  }
}
