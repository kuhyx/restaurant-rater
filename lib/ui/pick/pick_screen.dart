/// What to eat here — the app's whole point.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/logic/pick_dish.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/models/restaurant.dart';
import 'package:restaurant_rater/models/tasting.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/ui/common/rater_scope.dart';
import 'package:restaurant_rater/ui/menu/menu_screen.dart';
import 'package:restaurant_rater/ui/pick/pick_actions.dart';
import 'package:restaurant_rater/ui/pick/pick_card.dart';
import 'package:restaurant_rater/ui/rating/rating_screen.dart';

/// Offers the next dish at one restaurant, and commits that offer.
///
/// The commit is what makes the pick *sticky*: opening this screen writes the
/// chosen dish onto the restaurant, so closing the app on the walk to the
/// counter and opening it again at the till shows the same dish rather than
/// re-rolling. Without the write, "the next unrated dish" would still be
/// stable — but a skip, or a rating made on the other phone, would silently
/// change the answer between two looks at the screen.
class PickScreen extends StatelessWidget {
  /// Creates the pick screen for [restaurantId].
  const PickScreen({
    required this.repository,
    required this.photos,
    required this.restaurantId,
    super.key,
  });

  /// The data.
  final RaterRepository repository;

  /// On-device photo storage.
  final PhotoStore photos;

  /// Which restaurant.
  final String restaurantId;

  @override
  Widget build(BuildContext context) => RaterScope(
    repository: repository,
    builder: (context, snapshot) {
      final restaurant = snapshot.restaurantById(restaurantId);
      return Scaffold(
        appBar: AppBar(
          title: Text(restaurant?.name ?? 'Pick'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.restaurant_menu),
              tooltip: 'Menu',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MenuScreen(
                    repository: repository,
                    restaurantId: restaurantId,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: restaurant == null
            ? const EmptyState(
                icon: Icons.storefront,
                title: 'Restaurant is gone',
                message: 'It was deleted, here or on another device.',
              )
            : _PickBody(
                repository: repository,
                photos: photos,
                restaurant: restaurant,
                snapshot: snapshot,
              ),
      );
    },
  );
}

class _PickBody extends StatefulWidget {
  const _PickBody({
    required this.repository,
    required this.photos,
    required this.restaurant,
    required this.snapshot,
  });

  final RaterRepository repository;
  final PhotoStore photos;
  final Restaurant restaurant;
  final RaterSnapshot snapshot;

  @override
  State<_PickBody> createState() => _PickBodyState();
}

class _PickBodyState extends State<_PickBody> {
  /// The dish the caption below currently describes.
  String? _shownItemId;

  /// Why that dish was chosen, captured when it was chosen.
  ///
  /// Latched rather than recomputed for display, because committing the pick
  /// changes the answer. The first evaluation on a fresh screen says
  /// `nextUnrated`; the commit then writes `pending`, the change stream fires,
  /// and the next evaluation says `sticky` — so the very first thing the user
  /// ever sees would read "Still on this one" about a dish they had never been
  /// offered. Latching keeps the caption describing the decision that was
  /// actually made, while a genuine cold start still reads `sticky` first and
  /// says so correctly.
  PickReason? _shownReason;

  @override
  void initState() {
    super.initState();
    _syncPick();
  }

  @override
  void didUpdateWidget(_PickBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPick();
  }

  /// Latches the caption and persists the offer, unless already committed.
  ///
  /// The commit is guarded on inequality because this runs on every rebuild,
  /// and a write fires the change stream, which rebuilds — an unguarded commit
  /// would spin forever and push on every turn.
  void _syncPick() {
    final result = _pick();
    final item = result.item;
    if (item == null) {
      _shownItemId = null;
      _shownReason = null;
      return;
    }
    if (_shownItemId != item.id) {
      _shownItemId = item.id;
      _shownReason = result.reason;
    }
    if (widget.restaurant.pendingItemId == item.id) return;
    unawaited(
      widget.repository.commitPick(
        restaurantId: widget.restaurant.id,
        menuItemId: item.id,
      ),
    );
  }

  PickResult _pick() => pickNext(
    restaurant: widget.restaurant,
    menu: _menu,
    tastings: _tastings,
  );

  List<MenuItem> get _menu => widget.snapshot.menuOf(widget.restaurant.id);

  List<Tasting> get _tastings =>
      widget.snapshot.tastingsOf(widget.restaurant.id);

  Future<void> _skip(MenuItem item) => widget.repository.skipMenuItem(
    menuItemId: item.id,
    at: DateTime.now().toUtc(),
  );

  void _rate(MenuItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RatingScreen(
          repository: widget.repository,
          photos: widget.photos,
          item: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _pick();
    final item = result.item;
    if (item == null) {
      return const EmptyState(
        icon: Icons.restaurant_menu,
        title: 'No dishes yet',
        message: 'Add the menu, then come back and it will pick one.',
      );
    }
    return ListView(
      children: <Widget>[
        PickCard(item: item, reason: _shownReason ?? result.reason),
        PickActions(
          onRate: () => _rate(item),
          onSkip: () => unawaited(_skip(item)),
          canSkip: canSkipToAnother(menu: _menu, tastings: _tastings),
        ),
      ],
    );
  }
}
