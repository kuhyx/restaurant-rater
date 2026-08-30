/// The single seam every write passes through.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/record_ids.dart';
import 'package:restaurant_rater/sync/record_writer.dart';
import 'package:restaurant_rater/sync/restaurant_codec.dart';

import '../support/builders.dart';
import 'fake_log_persistence.dart';

void main() {
  const at = Hlc(wallTimeMs: 1000, counter: 0, nodeId: 'device-a');

  late LogStore store;
  late RecordWriter writer;

  setUp(() {
    store = LogStore(persistence: FakeLogPersistence(), nodeId: 'device-a');
    writer = RecordWriter(store);
  });

  test('a first write is stored as built', () async {
    await writer.upsertMerged(restaurantToRecord(aRestaurant(), at));

    expect(writer.restaurant('r1')?.name, 'Bar Tajski');
  });

  test('a field-scoped write keeps every field it does not name', () async {
    await writer.upsertMerged(restaurantToRecord(aRestaurant(), at));

    await writer.writePick('r1', 'm1');

    final restaurant = writer.restaurant('r1');
    expect(restaurant?.pendingItemId, 'm1');
    expect(restaurant?.name, 'Bar Tajski', reason: 'the name must survive');
  });

  test('untouched fields keep their original clock', () async {
    await writer.upsertMerged(restaurantToRecord(aRestaurant(), at));

    await writer.writePick('r1', 'm1');

    // A field that did not change must not outrank a peer's concurrent edit
    // to it, so its clock has to stay where it was.
    final stored = store.get(recordId(kRestaurantPrefix, 'r1'))!;
    expect(stored.fields[kNameField]?.$2, at);
    expect(stored.fields[kPendingField]?.$2, isNot(at));
  });

  test('a write to an absent record is a no-op, not a resurrection', () async {
    await writer.writePick('ghost', 'm1');

    expect(store.get(recordId(kRestaurantPrefix, 'ghost')), isNull);
  });

  test('a tombstone stays a tombstone through a merge', () async {
    await writer.upsertMerged(restaurantToRecord(aRestaurant(), at));
    await store.delete(recordId(kRestaurantPrefix, 'r1'));

    await writer.upsertMerged(restaurantToRecord(aRestaurant(), at));

    expect(writer.restaurant('r1'), isNull);
  });

  test('the skip stamp round-trips as UTC', () async {
    await writer.upsertMerged(menuItemToRecord(aMenuItem(), at));

    await writer.writeSkip('m1', DateTime.utc(2026, 8, 30, 18));

    expect(writer.menuItem('m1')?.skippedAt, DateTime.utc(2026, 8, 30, 18));
  });

  test('a cleared skip reads as never skipped', () async {
    await writer.upsertMerged(menuItemToRecord(aMenuItem(), at));
    await writer.writeSkip('m1', DateTime.utc(2026, 8, 30, 18));

    await writer.writeSkip('m1', null);

    expect(writer.menuItem('m1')?.isSkipped, isFalse);
  });

  test('an absent dish decodes to null rather than throwing', () {
    expect(writer.menuItem('nope'), isNull);
  });
}
