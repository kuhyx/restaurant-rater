/// Where dish photos live on this device.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:restaurant_rater/logic/photo_orphans.dart';

/// The directory name, under application support, holding dish photos.
const String kPhotoDirName = 'photos';

/// Reads and writes dish photos as files in the app's own storage.
///
/// Photos never enter the CRDT log and never reach Firebase: the transport is
/// a JSON tree and is not sized for image blobs. Only the filename syncs, so a
/// tasting rated on the phone shows its photo on the phone and a placeholder
/// everywhere else — see [PhotoStore.exists], which the UI asks before it
/// tries to render.
class PhotoStore {
  /// Wraps [directory]. Injected rather than resolved, so tests get a temp dir.
  PhotoStore(this.directory);

  /// Opens the real store at `<application-support>/photos`.
  static Future<PhotoStore> open() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, kPhotoDirName));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return PhotoStore(dir);
  }

  /// Where the files are.
  final Directory directory;

  /// The filename a tasting's photo takes.
  ///
  /// Derived from the tasting id, which is minted when the rating screen opens
  /// — before the camera is reached — so the file is written under its final
  /// name and never has to be renamed when Save is finally pressed.
  static String nameFor(String tastingId) => '$tastingId.jpg';

  /// The file for [name], whether or not it exists.
  File fileFor(String name) => File(p.join(directory.path, name));

  /// Whether [name]'s bytes are on this device.
  ///
  /// False is a normal answer, not an error: it means the photo was taken on
  /// another device and only its name reached here.
  bool exists(String name) => fileFor(name).existsSync();

  /// Copies [source] in under [tastingId]'s name and returns that name.
  ///
  /// The copy is immediate and not deferred. `image_picker` hands back a path
  /// inside the OS cache directory, which Android is free to purge at any
  /// moment — including between taking the photo and pressing Save.
  Future<String> save(File source, String tastingId) async {
    final name = nameFor(tastingId);
    if (!directory.existsSync()) await directory.create(recursive: true);
    await source.copy(p.join(directory.path, name));
    return name;
  }

  /// Deletes [name] if it is here. Absent is success, not an error.
  Future<void> remove(String name) async {
    final file = fileFor(name);
    if (file.existsSync()) await file.delete();
  }

  /// Every filename currently stored.
  Set<String> listNames() {
    if (!directory.existsSync()) return <String>{};
    return <String>{
      for (final entity in directory.listSync())
        if (entity is File) p.basename(entity.path),
    };
  }

  /// Deletes photos no live tasting refers to, returning how many went.
  ///
  /// Refuses to do anything when [logIsEmpty], which is the guard described at
  /// length on [canSweep]: an empty log looks exactly like "nothing is
  /// referenced", and acting on that would delete every photo on the device
  /// after a single truncated write.
  Future<int> sweep({
    required Set<String> referenced,
    required bool logIsEmpty,
  }) async {
    if (!canSweep(logIsEmpty: logIsEmpty)) return 0;
    final orphans = orphanPhotos(onDisk: listNames(), referenced: referenced);
    for (final name in orphans) {
      await remove(name);
    }
    return orphans.length;
  }
}
