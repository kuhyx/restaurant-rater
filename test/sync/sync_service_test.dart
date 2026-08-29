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

  test('the RTDB prefix is a constant: there are no flavors here', () {
    expect(kSyncPathPrefix, 'restaurant-rater/devices');
    expect(kSyncApp.expectedUid, kSyncUid);
    expect(kSyncApp.project, kSyncProject);
  });
}
