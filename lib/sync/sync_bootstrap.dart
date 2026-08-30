/// Assembling the synced repository at startup.
library;

import 'dart:async';
import 'dart:io';

import 'package:crdt_sync/crdt_sync.dart';
import 'package:crdt_sync/crdt_sync_io.dart';
import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/sync/coalesced_tick.dart';
import 'package:restaurant_rater/sync/crdt_rater_repository.dart';
import 'package:restaurant_rater/sync/sync_service.dart';

/// The synced repository, plus the tick that pushes it.
class SyncedStore {
  /// Bundles [repository] with the [sync] that publishes its writes.
  const SyncedStore({
    required this.repository,
    required this.photos,
    required this.sync,
    required this.deviceId,
    required this.openClient,
  });

  /// What the app reads and writes through.
  final RaterRepository repository;

  /// Where dish photos live on this device.
  final PhotoStore photos;

  /// Runs one push/pull tick.
  final Future<SyncOutcome> Function() sync;

  /// The persisted per-install id this device's records are stored under.
  ///
  /// Exposed because verifying a sync means naming the exact remote path to
  /// read back, and only this side knows the id.
  final String deviceId;

  /// Opens a signed-in client, or null when this device has no session.
  final Future<RemoteStore?> Function() openClient;
}

/// Builds the CRDT-backed repository and starts pushing its writes.
///
/// The order matters and is the whole safety argument:
///   1. hydrate the local log from disk;
///   2. only then sync, so the first push carries this device's real history
///      rather than an empty log a peer would merge as a mass deletion.
///
/// There is no migration step between them, unlike punchme: this app was born
/// synced and has no earlier on-disk format to read.
///
/// The photo sweep is gated on the log being non-empty. `LogStore.load()`
/// returns an empty log for a truncated or missing file rather than throwing,
/// and sweeping against that would see every photo on the device as an orphan
/// and delete all of them.
Future<SyncedStore> openSyncedStore({
  Directory? directory,
  PhotoStore? photoStore,
  Future<RemoteStore?> Function()? openClient,
  Future<DeviceIdentity> Function()? identity,
}) async {
  final dir = directory ?? await getApplicationSupportDirectory();
  final me = await (identity ?? loadDeviceIdentity)();

  final store = LogStore(
    persistence: FileLogPersistence(File(p.join(dir.path, kLogFileName))),
    nodeId: me.deviceId,
  );
  final loaded = await store.load();

  final stateStore = PersistedSyncStateStore(
    FileLogPersistence(File(p.join(dir.path, kSyncStateFileName))),
  );

  Future<RemoteStore?> open() =>
      openClient == null ? openSync(kSyncApp) : openClient();

  Future<SyncOutcome> tick() => syncNow(
    store: store,
    deviceId: me.deviceId,
    openClient: open,
    stateStore: stateStore,
  );

  final pushSoon = CoalescedTick(tick);

  final repository = CrdtRaterRepository(store: store);
  final photos = photoStore ?? await PhotoStore.open();

  await photos.sweep(
    referenced: repository.snapshot().referencedPhotos(),
    logIsEmpty: loaded.isEmpty,
  );

  // Driven from the store's own change stream rather than a callback the
  // repository has to remember to fire: this cannot be forgotten by a method
  // added later. Fire-and-forget, because a rating must land on screen at once
  // and is already durable locally by the time this runs; a failed push is not
  // an error the user has to dismiss.
  store.changes.listen((_) => unawaited(pushSoon()));

  return SyncedStore(
    deviceId: me.deviceId,
    openClient: open,
    repository: repository,
    photos: photos,
    sync: tick,
  );
}
