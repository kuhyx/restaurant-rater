/// Every rating, newest first.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/ui/common/rater_scope.dart';
import 'package:restaurant_rater/ui/history/tasting_tile.dart';

/// The full tasting history across every restaurant.
class HistoryScreen extends StatelessWidget {
  /// Creates the history screen.
  const HistoryScreen({
    required this.repository,
    required this.photos,
    super.key,
  });

  /// The data.
  final RaterRepository repository;

  /// On-device photo storage.
  final PhotoStore photos;

  Future<void> _delete(BuildContext context, Tasting tasting) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this rating?',
      message: 'The dish stays on the menu and goes back to untried.',
    );
    if (!confirmed) return;
    await repository.deleteTasting(tasting.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('History')),
    body: RaterScope(
      repository: repository,
      builder: _body,
    ),
  );

  Widget _body(BuildContext context, RaterSnapshot snapshot) {
    final tastings = snapshot.tastings.toList()
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    if (tastings.isEmpty) {
      return const EmptyState(
        icon: Icons.star_outline,
        title: 'Nothing rated yet',
        message: 'Pick a restaurant and rate what it offers you.',
      );
    }
    return ListView.builder(
      itemCount: tastings.length,
      itemBuilder: (context, index) {
        final tasting = tastings[index];
        return TastingTile(
          tasting: tasting,
          // A tasting whose dish or restaurant is gone is filtered out at load
          // — these fallbacks cover a record mid-merge, not a normal state.
          dishName: snapshot.menuItemById(tasting.menuItemId)?.name ?? 'Dish',
          restaurantName:
              snapshot.restaurantById(tasting.restaurantId)?.name ?? '',
          photos: photos,
          onDelete: () => _delete(context, tasting),
        );
      },
    );
  }
}
