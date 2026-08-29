/// A restaurant's menu, in the order the dishes were typed in.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/logic/scores.dart';
import 'package:restaurant_rater/models/menu_item.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';
import 'package:restaurant_rater/ui/common/rater_scope.dart';
import 'package:restaurant_rater/ui/menu/menu_item_editor.dart';
import 'package:restaurant_rater/ui/menu/menu_item_tile.dart';

/// Lists and edits one restaurant's dishes.
class MenuScreen extends StatelessWidget {
  /// Creates the menu screen for [restaurantId].
  const MenuScreen({
    required this.repository,
    required this.restaurantId,
    super.key,
  });

  /// The data.
  final RaterRepository repository;

  /// Whose menu this is.
  final String restaurantId;

  Future<void> _add(BuildContext context) async {
    final draft = await editMenuItemDialog(context);
    if (draft == null) return;
    await repository.addMenuItem(
      restaurantId: restaurantId,
      name: draft.name,
      priceGrosz: draft.priceGrosz,
    );
  }

  Future<void> _edit(BuildContext context, MenuItem item) async {
    final draft = await editMenuItemDialog(context, existing: item);
    if (draft == null) return;
    await repository.editMenuItem(
      id: item.id,
      name: draft.name,
      priceGrosz: draft.priceGrosz,
    );
  }

  Future<void> _delete(BuildContext context, MenuItem item) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${item.name}?',
      message: 'Its ratings go too. This cannot be undone.',
    );
    if (!confirmed) return;
    await repository.deleteMenuItem(item.id);
  }

  @override
  Widget build(BuildContext context) => RaterScope(
    repository: repository,
    builder: (context, snapshot) {
      final restaurant = snapshot.restaurantById(restaurantId);
      return Scaffold(
        appBar: AppBar(title: Text(restaurant?.name ?? 'Menu')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _add(context),
          tooltip: 'Add dish',
          child: const Icon(Icons.add),
        ),
        body: _body(context, snapshot),
      );
    },
  );

  Widget _body(BuildContext context, RaterSnapshot snapshot) {
    final menu = snapshot.menuOf(restaurantId);
    if (menu.isEmpty) {
      return const EmptyState(
        icon: Icons.restaurant_menu,
        title: 'No dishes yet',
        message: 'Type them in the order they appear on the menu.',
      );
    }
    final tastings = snapshot.tastingsOf(restaurantId);
    return ListView.builder(
      itemCount: menu.length,
      itemBuilder: (context, index) {
        final item = menu[index];
        return MenuItemTile(
          item: item,
          score: meanOverall(
            tastings.where((tasting) => tasting.menuItemId == item.id),
          ),
          onEdit: () => _edit(context, item),
          onDelete: () => _delete(context, item),
        );
      },
    );
  }
}
