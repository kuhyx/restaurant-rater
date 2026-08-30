/// Pushing the local log to Firebase, and pulling every peer's back.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';

/// The shared `kuhy-syncs` project.
///
/// Safe to commit: the Web API key is a public identifier that already ships
/// inside every APK, and the security rules -- not its secrecy -- are what
/// protect the data.
const FirebaseProject kSyncProject = FirebaseProject(
  apiKey: 'AIzaSyCF_sA3xCMehAYXK8eND-rAygb9NXXW_8E',
  databaseUrl:
      'https://kuhy-syncs-default-rtdb.europe-west1.firebasedatabase.app',
);

/// The uid the database rules pin.
const String kSyncUid = 'OvA2REQyLIhAHOEjzwS1o877rgG3';

/// This app's descriptor for the shared bootstrap.
const SyncApp kSyncApp = SyncApp(project: kSyncProject, expectedUid: kSyncUid);

/// The RTDB path this app's devices push under.
///
/// A constant, unlike punchme's, which derives the segment from a build
/// flavor: there is no sandbox build here to keep away from the real data.
const String kSyncPathPrefix = 'restaurant-rater/devices';

/// The log file's name in application support.
const String kLogFileName = 'rater_log.json';

/// The sync-state file's name, holding the last-seen revision per peer.
const String kSyncStateFileName = 'rater_sync_state.json';

/// What a sync attempt did.
enum SyncOutcome {
  /// This device is not enrolled; nothing was pushed or pulled.
  notConfigured,

  /// The log was pushed, and every peer's merged in.
  synced,
}

/// Merges the local log with every peer's, then pushes the result.
///
/// [openClient] is injected so the whole path is exercisable without a network
/// or a keystore.
///
/// Returns [SyncOutcome.notConfigured] when this device has no session. That
/// is a normal state, not an error -- the app keeps working against its local
/// store -- but it is reported rather than swallowed so a caller can tell
/// "synced" from "silently did nothing", which is the difference between a
/// working sync and one that has never once run.
///
/// [stateStore] is not optional in practice. Without it `syncLog` has no
/// record of which peer revisions it has already seen, so every tick
/// re-downloads and re-uploads the entire log -- unnoticeable with two
/// restaurants and ruinous with two hundred.
Future<SyncOutcome> syncNow({
  required LogStore store,
  required String deviceId,
  required Future<RemoteStore?> Function() openClient,
  required SyncStateStore stateStore,
  String pathPrefix = kSyncPathPrefix,
}) async {
  final client = await openClient();
  if (client == null) return SyncOutcome.notConfigured;

  final merged = await syncLog(
    client: client,
    deviceId: deviceId,
    pathPrefix: pathPrefix,
    localLog: store.snapshot(),
    encode: logToJson,
    decode: logFromJson,
    commitMessage: 'restaurant-rater sync',
    stateStore: stateStore,
  );
  // Re-merged against the log as it is NOW, not as it was before the
  // round-trip. `syncLog` computed [merged] from a snapshot taken before any
  // network I/O, so a local write that landed while the request was in flight
  // is not in it — and replacing outright would erase that write with no
  // trace.
  //
  // That is not hypothetical: importing a menu writes one record per dish, so
  // a paste lands a burst of writes straight into the window a tick triggered
  // by the previous write is already sitting in. It cost a dish on the phone
  // before this line existed.
  //
  // Safe because `mergeLogs` is commutative and idempotent: re-merging the
  // local side back in cannot resurrect a tombstone or lose a remote edit.
  final settled = mergeLogs(store.snapshot(), merged);

  // Written back only when it actually differs, and that is load-bearing:
  // `LogStore.replaceAll` persists, persisting fires `changes`, and `changes`
  // is what schedules the next tick. An unconditional write-back therefore
  // schedules a tick that writes back that schedules a tick — a sync loop that
  // never settles, one network round-trip per turn, for as long as the app is
  // open. Comparing the encoded form rather than the maps because `Log` is a
  // plain Map and `==` on it is identity; this is the same text the transport
  // sends, so equal text is an equal log.
  if (logToJson(settled) != logToJson(store.snapshot())) {
    await store.replaceAll(settled);
  }
  return SyncOutcome.synced;
}
