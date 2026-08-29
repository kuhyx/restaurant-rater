/// The three record codecs, and the null-vs-omit discipline they enforce.
library;

import 'package:crdt_sync/crdt_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/models/macros.dart';
import 'package:restaurant_rater/sync/menu_item_codec.dart';
import 'package:restaurant_rater/sync/record_ids.dart';
import 'package:restaurant_rater/sync/restaurant_codec.dart';
import 'package:restaurant_rater/sync/tasting_codec.dart';

import '../support/builders.dart';

void main() {
  const at = Hlc(wallTimeMs: 1000, counter: 0, nodeId: 'device-a');
  const later = Hlc(wallTimeMs: 2000, counter: 0, nodeId: 'device-a');

  group('record ids', () {
    test('prefix and strip round-trip', () {
      final id = recordId(kRestaurantPrefix, 'abc');
      expect(id, 'r:abc');
      expect(bareId(id, kRestaurantPrefix), 'abc');
    });

    test('a record of another kind strips to null, not an error', () {
      // Every decoder walks the whole log, so "not mine" is the common case.
      expect(bareId('m:abc', kRestaurantPrefix), isNull);
    });
  });

  group('restaurant', () {
    test('round-trips', () {
      final original = aRestaurant(note: 'by the tram stop');
      final decoded = recordToRestaurant(restaurantToRecord(original, at))!;
      expect(decoded.id, original.id);
      expect(decoded.name, original.name);
      expect(decoded.note, original.note);
      expect(decoded.createdAt, original.createdAt);
    });

    test('never writes the pick field', () {
      // Load-bearing: only commitPick/clearPick own that field, so a rename
      // cannot stamp a stale pick over a peer's fresh one.
      final record = restaurantToRecord(
        aRestaurant(pendingItemId: 'm1'),
        at,
        includeCleared: true,
      );
      expect(record.fields.containsKey(kPendingField), isFalse);
    });

    test('omits an absent note on create but nulls it on edit', () {
      expect(
        restaurantToRecord(aRestaurant(), at).fields.containsKey(kNoteField),
        isFalse,
        reason: 'nothing on any peer to lose yet',
      );
      final edited = restaurantToRecord(
        aRestaurant(),
        at,
        includeCleared: true,
      );
      expect(edited.fields[kNoteField]?.$1, isNull);
      expect(edited.fields.containsKey(kNoteField), isTrue);
    });

    test('decodes the pick when the log carries one', () {
      final record = Record(
        id: 'r:r1',
        fields: <String, Field>{
          kNameField: ('Bar Tajski', at),
          kPendingField: ('m1', at),
        },
      );
      expect(recordToRestaurant(record)!.pendingItemId, 'm1');
    });

    test('rejects a tombstone, a foreign kind, and a nameless record', () {
      expect(
        recordToRestaurant(Record(id: 'r:r1', fields: const {}, deleted: true)),
        isNull,
      );
      expect(recordToRestaurant(Record(id: 'm:m1', fields: const {})), isNull);
      expect(recordToRestaurant(Record(id: 'r:r1', fields: const {})), isNull);
    });

    test('survives a record with no createdAt', () {
      final record = Record(
        id: 'r:r1',
        fields: <String, Field>{kNameField: ('Bar Tajski', at)},
      );
      expect(recordToRestaurant(record)!.createdAt.millisecondsSinceEpoch, 0);
    });

    test('treats an empty note or pick as absent', () {
      final record = Record(
        id: 'r:r1',
        fields: <String, Field>{
          kNameField: ('Bar Tajski', at),
          kNoteField: ('', at),
          kPendingField: ('', at),
        },
      );
      expect(recordToRestaurant(record)!.note, isNull);
      expect(recordToRestaurant(record)!.pendingItemId, isNull);
    });
  });

  group('menu item', () {
    test('round-trips', () {
      final original = aMenuItem(orderKey: 'k');
      final decoded = recordToMenuItem(menuItemToRecord(original, at))!;
      expect(decoded.id, original.id);
      expect(decoded.restaurantId, original.restaurantId);
      expect(decoded.name, original.name);
      expect(decoded.orderKey, 'k');
      expect(decoded.priceGrosz, 2400);
    });

    test('never writes the skip field', () {
      final record = menuItemToRecord(
        aMenuItem(skippedAt: kEpoch),
        at,
        includeCleared: true,
      );
      expect(record.fields.containsKey(kSkippedAtField), isFalse);
    });

    test('falls back to the record id when orderKey is missing', () {
      // A dish written by a build predating the field keeps a fixed position
      // rather than jumping around on every load.
      final record = Record(
        id: 'm:m1',
        fields: <String, Field>{
          kRestaurantField: ('r1', at),
          kItemNameField: ('tom kha', at),
        },
      );
      expect(recordToMenuItem(record)!.orderKey, 'm1');
    });

    test('rejects a price that arrived as a double', () {
      // Grosz are integers; a double here means drift worth catching, not
      // rounding.
      final record = Record(
        id: 'm:m1',
        fields: <String, Field>{
          kRestaurantField: ('r1', at),
          kItemNameField: ('tom kha', at),
          kPriceField: (24.5, at),
        },
      );
      expect(recordToMenuItem(record)!.priceGrosz, isNull);
    });

    test('rejects a tombstone, a foreign kind, and a nameless record', () {
      expect(
        recordToMenuItem(Record(id: 'm:m1', fields: const {}, deleted: true)),
        isNull,
      );
      expect(recordToMenuItem(Record(id: 'r:r1', fields: const {})), isNull);
      expect(recordToMenuItem(Record(id: 'm:m1', fields: const {})), isNull);
    });

    test('decodes a skip stamp', () {
      final record = Record(
        id: 'm:m1',
        fields: <String, Field>{
          kRestaurantField: ('r1', at),
          kItemNameField: ('tom kha', at),
          kSkippedAtField: ('2026-08-29T12:00:00.000Z', at),
        },
      );
      expect(recordToMenuItem(record)!.skippedAt, kEpoch);
    });
  });

  group('tasting', () {
    test('round-trips, with macros flattened into sibling fields', () {
      final original = aTasting(
        macros: const Macros(kcal: 320, proteinG: 24, fatG: 9, carbsG: 30),
        photoName: 'p.jpg',
        note: 'too salty',
        priceGrosz: 2200,
      );
      final record = tastingToRecord(original, at);
      expect(record.fields['kcal']?.$1, 320.0, reason: 'flat, not nested');
      final decoded = recordToTasting(record)!;
      expect(decoded, original);
    });

    test('omits unfilled optionals on create, nulls them on edit', () {
      final created = tastingToRecord(aTasting(), at);
      expect(created.fields.containsKey(kPhotoField), isFalse);
      final edited = tastingToRecord(aTasting(), at, includeCleared: true);
      expect(edited.fields[kPhotoField]?.$1, isNull);
    });

    test(
      'keeps a rating whose scores are unreadable rather than dropping it',
      () {
        final record = Record(
          id: 't:t1',
          fields: <String, Field>{
            kMenuItemField: ('m1', at),
            kTastingRestaurantField: ('r1', at),
          },
        );
        final decoded = recordToTasting(record)!;
        expect(decoded.taste, 0);
        expect(decoded.eatenAt.millisecondsSinceEpoch, 0);
      },
    );

    test('clamps an out-of-range score from another build', () {
      final record = Record(
        id: 't:t1',
        fields: <String, Field>{
          kMenuItemField: ('m1', at),
          kTastingRestaurantField: ('r1', at),
          kTasteField: (99, at),
        },
      );
      expect(recordToTasting(record)!.taste, 10);
    });

    test('rejects a tombstone, a foreign kind, and a dangling rating', () {
      expect(
        recordToTasting(Record(id: 't:t1', fields: const {}, deleted: true)),
        isNull,
      );
      expect(recordToTasting(Record(id: 'r:r1', fields: const {})), isNull);
      expect(recordToTasting(Record(id: 't:t1', fields: const {})), isNull);
    });
  });

  group('merging', () {
    test('two devices editing different fields keep both edits', () {
      final phone = tastingToRecord(aTasting(taste: 9), at);
      final desktop = Record(
        id: phone.id,
        fields: <String, Field>{kSmellField: (1, later)},
      );
      final merged = recordToTasting(mergeRecord(phone, desktop))!;
      expect(merged.taste, 9, reason: 'the phone owned this field');
      expect(merged.smell, 1, reason: 'the desktop wrote it later');
    });
  });
}
