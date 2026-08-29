/// On-device photo storage, and the sweep that must not run blind.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:restaurant_rater/photos/photo_store.dart';

void main() {
  late Directory root;
  late PhotoStore photos;

  setUp(() {
    root = Directory.systemTemp.createTempSync('rater-photos');
    photos = PhotoStore(Directory(p.join(root.path, kPhotoDirName)));
  });

  tearDown(() => root.deleteSync(recursive: true));

  File sourceFile(String name) {
    final file = File(p.join(root.path, name))
      ..writeAsBytesSync(<int>[1, 2, 3]);
    return file;
  }

  test('names a photo after its tasting, so it never needs renaming', () {
    // The tasting id is minted when the rating screen opens, before the
    // camera is reached, which is what makes this possible.
    expect(PhotoStore.nameFor('abc'), 'abc.jpg');
  });

  test('save copies the bytes in and returns the bare name', () async {
    final name = await photos.save(sourceFile('from-cache.jpg'), 'abc');
    expect(name, 'abc.jpg');
    expect(photos.exists(name), isTrue);
    expect(photos.fileFor(name).readAsBytesSync(), <int>[1, 2, 3]);
  });

  test('save copies rather than moves', () async {
    // image_picker hands back a path in the OS cache directory, which Android
    // may purge between the shutter and the Save button.
    final source = sourceFile('from-cache.jpg');
    await photos.save(source, 'abc');
    expect(source.existsSync(), isTrue);
  });

  test('exists is false for a photo taken on another device', () {
    // A normal, permanent state -- only the filename syncs.
    expect(photos.exists('elsewhere.jpg'), isFalse);
  });

  test('remove deletes, and removing an absent file is not an error', () async {
    final name = await photos.save(sourceFile('a.jpg'), 'abc');
    await photos.remove(name);
    expect(photos.exists(name), isFalse);
    await photos.remove(name);
    await photos.remove('never-existed.jpg');
  });

  test('listNames is empty before anything is stored', () {
    expect(photos.listNames(), isEmpty);
  });

  test('listNames reports every stored file', () async {
    await photos.save(sourceFile('a.jpg'), 'one');
    await photos.save(sourceFile('b.jpg'), 'two');
    expect(photos.listNames(), <String>{'one.jpg', 'two.jpg'});
  });

  group('sweep', () {
    test('deletes only the unreferenced', () async {
      await photos.save(sourceFile('a.jpg'), 'keep');
      await photos.save(sourceFile('b.jpg'), 'drop');

      final removed = await photos.sweep(
        referenced: <String>{'keep.jpg'},
        logIsEmpty: false,
      );

      expect(removed, 1);
      expect(photos.exists('keep.jpg'), isTrue);
      expect(photos.exists('drop.jpg'), isFalse);
    });

    test('DELETES NOTHING when the log is empty', () async {
      // The most destructive failure this app could have. LogStore.load()
      // returns an empty log for a truncated or missing file rather than
      // throwing, so an empty log is indistinguishable from "no photo is
      // referenced" -- and sweeping on that would delete every photo the
      // user owns, permanently, for a fault the next sync would have fixed.
      await photos.save(sourceFile('a.jpg'), 'precious');

      final removed = await photos.sweep(
        referenced: const <String>{},
        logIsEmpty: true,
      );

      expect(removed, 0);
      expect(photos.exists('precious.jpg'), isTrue);
    });

    test('is a no-op when nothing is stored yet', () async {
      expect(
        await photos.sweep(referenced: const <String>{}, logIsEmpty: false),
        0,
      );
    });
  });
}
