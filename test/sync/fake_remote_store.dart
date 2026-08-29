/// An in-memory RemoteStore, so sync tests need no network.
library;

import 'package:crdt_sync/crdt_sync.dart';

/// Dumb keyed text storage that records every write.
///
/// The whole remote surface is six methods over text blobs, which is exactly
/// why the transport is swappable — and why a fake is this small.
class FakeRemoteStore implements RemoteStore {
  /// Path -> payload, for everything written through this store.
  final Map<String, String> written = <String, String>{};

  final Map<String, String> _files = <String, String>{};

  /// Whether [close] has been called.
  bool closed = false;

  /// Pre-loads a peer's file at [path].
  void seed(String path, String contents) => _files[path] = contents;

  @override
  Future<List<String>> listDirectory(String path) async {
    final prefix = path.endsWith('/') ? path : '$path/';
    return <String>{
      for (final key in _files.keys)
        if (key.startsWith(prefix))
          key.substring(prefix.length).split('/').first,
    }.toList(growable: false);
  }

  @override
  Future<String?> getFileText(String path) async => _files[path];

  @override
  Future<void> putFileText(
    String path,
    String text, {
    required String message,
  }) async {
    written[path] = text;
    _files[path] = text;
  }

  @override
  Future<void> deleteFile(String path, {String message = ''}) async {
    _files.remove(path);
  }

  @override
  Future<bool> canAccessRemote() async => true;

  @override
  void close() => closed = true;
}
