/// Sync state, and a way to prove sync actually runs.
library;

import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/ui/import/import_screen.dart';
import 'package:restaurant_rater/ui/settings/sync_actions.dart';

/// Connecting this device, and running a sync on demand.
class SettingsScreen extends StatefulWidget {
  /// Creates the settings screen.
  const SettingsScreen({
    required this.repository,
    required this.sync,
    this.syncProbe = probeSyncSession,
    this.syncConnect = connectSyncAccount,
    super.key,
  });

  /// The data.
  final RaterRepository repository;

  /// Runs one push/pull tick.
  final Future<SyncOutcome> Function() sync;

  /// Reports whether this device holds a session.
  ///
  /// Injected, with the real implementations as defaults, because both reach
  /// platform channels `flutter test` has no host for -- and an unanswered
  /// channel *hangs* the test file rather than failing it, which writes no
  /// coverage at all for anything else in the run.
  final SyncProbe syncProbe;

  /// Performs the interactive sign-in.
  final SyncConnect syncConnect;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _syncing = false;

  /// Runs a tick and says what it did.
  ///
  /// The button exists because the automatic push is fire-and-forget and
  /// swallows its errors — which is right for a rating that must land on
  /// screen at once, and useless for answering "is sync working?". This is the
  /// one path that reports the outcome, including
  /// [SyncOutcome.notConfigured], which is what a device with no session
  /// silently does on every other tick.
  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    String message;
    try {
      final outcome = await widget.sync();
      message = switch (outcome) {
        SyncOutcome.synced => 'Synced.',
        SyncOutcome.notConfigured =>
          'Not connected — nothing was pushed or pulled.',
      };
    } on Object catch (error) {
      message = 'Sync failed: $error';
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    showToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.repository.snapshot();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const SectionHeader('Sync'),
          SyncActions(probe: widget.syncProbe, connect: widget.syncConnect),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sync now'),
            subtitle: const Text(
              'Pushes this device and pulls every other one.',
            ),
            trailing: _syncing
                ? const SizedBox(
                    width: AppSpacing.lg,
                    height: AppSpacing.lg,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onTap: _syncing ? null : () => unawaited(_syncNow()),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Menus'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Import a menu'),
            subtitle: const Text(
              'Photograph a menu, have Claude turn it into JSON, paste it '
              'here.',
            ),
            trailing: const Icon(Icons.content_paste_go),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ImportScreen(repository: widget.repository),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Photos'),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Photos stay on the device that took them'),
            subtitle: Text(
              'Scores, macros and notes sync. Image files do not: the sync '
              'transport is a JSON tree and is not sized for them.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('This device'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recorded'),
            subtitle: Text(
              '${snapshot.restaurants.length} restaurants, '
              '${snapshot.menuItems.length} dishes, '
              '${snapshot.tastings.length} ratings',
            ),
          ),
        ],
      ),
    );
  }
}
