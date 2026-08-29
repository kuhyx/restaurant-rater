/// Startup: hydrate, then sync, and never sweep against an empty log.
library;

import 'dart:io';

import 'package:crdt_sync/crdt_sync.dart';
import 'package:crdt_sync_flutter/crdt_sync_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:restaurant_rater/photos/photo_store.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/restaurant_codec.dart';
import 'package:restaurant_rater/sync/sync_bootstrap.dart';
import 'package:restaurant_rater/sync/sync_service.dart';
import 'package:restaurant_rater/sync/tasting_codec.dart';

import '../support/builders.dart';
import 'fake_remote_store.dart';

void main() {
  const at = Hlc(wallTimeMs: 1000, counter: 0, nodeId: 'device-a');

  late Directory dir;
  late PhotoStore photos;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rater-boot');
    photos = PhotoStore(Directory(p.join(dir.path, kPhotoDirName)))
      ..directory.createSync(recursive: true);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<DeviceIdentity> identity() async =>
      const DeviceIdentity(deviceId: 'device-a');

  /// Writes a log file the store will hydrate from.
  void seedLog(Log log) =>
      File(p.join(dir.path, kLogFileName)).writeAsStringSync(logToJson(log));

  Future<SyncedStore> boot({FakeRemoteStore? remote}) => openSyncedStore(
    directory: dir,
    photoStore: photos,
    identity: identity,
    openClient: () async => remote,
  );

  test('starts empty on a fresh install', () async {
    final store = await boot();
    expect(store.repository.snapshot().isEmpty, isTrue);
    expect(store.deviceId, 'device-a');
  });

  test('hydrates what was on disk before any sync runs', () async {
    // The order is the safety argument: sync before hydrate would push an
    // empty log that a peer merges as a mass deletion.
    seedLog(<String, Record>{
      'r:r1': restaurantToRecord(aRestaurant(), at),
    });

    final remote = FakeRemoteStore();
    final store = await boot(remote: remote);
    await store.sync();

    expect(store.repository.snapshot().restaurants.single.name, 'Bar Tajski');
    final pushed = remote.written.values.firstWhere(
      (text) => text.contains('r:r1'),
    );
    expect(pushed, contains('Bar Tajski'), reason: 'the real log was pushed');
  });

  test('reports notConfigured when no client can be opened', () async {
    final store = await boot();
    expect(await store.sync(), SyncOutcome.notConfigured);
    expect(await store.openClient(), isNull);
  });

  group('the photo sweep', () {
    test('DELETES NOTHING when the log is empty', () async {
      // The worst thing this app could do. LogStore.load() returns an empty
      // log for a truncated file rather than throwing, so a single bad write
      // would otherwise look like "no photo is referenced" and take every
      // photo on the device with it.
      photos.fileFor('precious.jpg').writeAsBytesSync(<int>[1]);

      await boot();

      expect(photos.exists('precious.jpg'), isTrue);
    });

    test('removes an orphan once the log has something in it', () async {
      seedLog(<String, Record>{
        'r:r1': restaurantToRecord(aRestaurant(), at),
      });
      photos.fileFor('orphan.jpg').writeAsBytesSync(<int>[1]);

      await boot();

      expect(photos.exists('orphan.jpg'), isFalse);
    });

    test('keeps a photo a live rating still names', () async {
      // The whole chain, because log_queries drops a rating whose dish is
      // gone -- seeding only the rating would make its photo an orphan, which
      // is correct behaviour and would not test what this test is about.
      seedLog(<String, Record>{
        'r:r1': restaurantToRecord(aRestaurant(), at),
        'm:m1': menuItemToRecord(aMenuItem(), at),
        't:t1': tastingToRecord(aTasting(photoName: 'kept.jpg'), at),
      });
      photos.fileFor('kept.jpg').writeAsBytesSync(<int>[1]);

      await boot();

      expect(photos.exists('kept.jpg'), isTrue);
    });
  });

  test('a write triggers a push without the caller awaiting it', () async {
    final remote = FakeRemoteStore();
    final store = await boot(remote: remote);

    await store.repository.addRestaurant(name: 'Tuk Tuk');
    // The listener is fire-and-forget, so give the microtask queue a turn.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(remote.written, isNotEmpty, reason: 'the write was pushed');
  });
}
