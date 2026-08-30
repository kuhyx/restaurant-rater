/// The push/pull tick, without a network or a keystore.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/sync/restaurant_codec.dart';
import 'package:restaurant_rater/sync/sync_service.dart';

import '../support/builders.dart';
import 'fake_log_persistence.dart';
import 'fake_remote_store.dart';

void main() {
  const at = Hlc(wallTimeMs: 1000, counter: 0, nodeId: 'device-a');

  late LogStore store;
  late SyncStateStore state;

  setUp(() {
    store = LogStore(persistence: FakeLogPersistence(), nodeId: 'device-a');
    state = InMemorySyncStateStore();
  });

  test('reports notConfigured when this device has no session', () async {
    // A normal state, not an error -- but it has to be reported, or a device
    // that never syncs is indistinguishable from one that always does.
    final outcome = await syncNow(
      store: store,
      deviceId: 'device-a',
      openClient: () async => null,
      stateStore: state,
    );
    expect(outcome, SyncOutcome.notConfigured);
  });

  test('pushes the local log under this device id', () async {
    await store.upsert(restaurantToRecord(aRestaurant(), at));
    final remote = FakeRemoteStore();

    final outcome = await syncNow(
      store: store,
      deviceId: 'device-a',
      openClient: () async => remote,
      stateStore: state,
    );

    expect(outcome, SyncOutcome.synced);
    // More than one write: the log itself, plus the revision marker the
    // state store uses to avoid re-downloading unchanged peers next tick.
    expect(
      remote.written.keys,
      anyElement(startsWith('restaurant-rater/devices/device-a')),
    );
  });

  test('merges a peer log in', () async {
    final remote = FakeRemoteStore()
      ..seed(
        'restaurant-rater/devices/device-b/log.json',
        logToJson(<String, Record>{
          'r:peer': restaurantToRecord(
            aRestaurant(id: 'peer', name: 'Tuk Tuk'),
            at,
          ),
        }),
      );

    await syncNow(
      store: store,
      deviceId: 'device-a',
      openClient: () async => remote,
      stateStore: state,
    );

    expect(store.snapshot().containsKey('r:peer'), isTrue);
  });

  test('a write during the round-trip is not erased by the write-back', () async {
    // The regression: `syncLog` computes its result from a snapshot taken
    // before any network I/O, so a record written while the request is in
    // flight is absent from it. Replacing the log outright therefore deleted
    // that record — which is exactly what importing a menu does, one write per
    // dish, straight into the window an earlier tick is already sitting in.
    // A dish vanished on the phone this way.
    final remote = FakeRemoteStore()
      ..onRead = () async {
        await store.upsert(
          restaurantToRecord(aRestaurant(id: 'late', name: 'Banh Mi'), at),
        );
      };

    await syncNow(
      store: store,
      deviceId: 'device-a',
      openClient: () async => remote,
      stateStore: state,
    );

    expect(store.snapshot().containsKey('r:late'), isTrue);
  });

  test('a tick that changes nothing writes nothing back', () async {
    // The loop this prevents: `replaceAll` persists, persisting fires
    // `changes`, and `changes` is what schedules the next tick. Writing back
    // unconditionally therefore schedules a tick that writes back that
    // schedules a tick, one network round-trip per turn, forever.
    await store.upsert(restaurantToRecord(aRestaurant(), at));
    var writes = 0;
    final sub = store.changes.listen((_) => writes++);
    addTearDown(sub.cancel);

    await syncNow(
      store: store,
      deviceId: 'device-a',
      openClient: () async => FakeRemoteStore(),
      stateStore: state,
    );
    await Future<void>.delayed(Duration.zero);

    expect(writes, 0, reason: 'a settled log must not re-fire changes');
  });

  test('a tick that pulls something new does write back', () async {
    var writes = 0;
    final sub = store.changes.listen((_) => writes++);
    addTearDown(sub.cancel);
    final remote = FakeRemoteStore()
      ..seed(
        'restaurant-rater/devices/device-b/log.json',
        logToJson(<String, Record>{
          'r:peer': restaurantToRecord(aRestaurant(id: 'peer'), at),
        }),
      );

    await syncNow(
      store: store,
      deviceId: 'device-a',
      openClient: () async => remote,
      stateStore: state,
    );
    await Future<void>.delayed(Duration.zero);

    expect(writes, 1);
  });

  test('the RTDB prefix is a constant: there are no flavors here', () {
    expect(kSyncPathPrefix, 'restaurant-rater/devices');
    expect(kSyncApp.expectedUid, kSyncUid);
    expect(kSyncApp.project, kSyncProject);
  });
}
