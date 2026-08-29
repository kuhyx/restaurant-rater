/// Which photo files may be deleted -- and when none of them may be.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_rater/logic/photo_orphans.dart';

void main() {
  test('an orphan is a file no live tasting names', () {
    expect(
      orphanPhotos(
        onDisk: <String>{'a.jpg', 'b.jpg', 'c.jpg'},
        referenced: <String>{'b.jpg'},
      ),
      <String>{'a.jpg', 'c.jpg'},
    );
  });

  test('a referenced file that is not on disk is not an orphan', () {
    // That is the photo-taken-on-another-device case, and it must never be
    // read as something to clean up.
    expect(
      orphanPhotos(onDisk: <String>{}, referenced: <String>{'elsewhere.jpg'}),
      isEmpty,
    );
  });

  test('canSweep refuses when the log is empty', () {
    // The guard that stops one truncated write from deleting every photo on
    // the device: LogStore.load() returns an EMPTY log for a corrupt file
    // rather than throwing, and an empty log references nothing.
    expect(canSweep(logIsEmpty: true), isFalse);
    expect(canSweep(logIsEmpty: false), isTrue);
  });
}
