/// An in-memory LogPersistence, so tests touch no file system.
library;

import 'package:crdt_sync/crdt_sync.dart';

/// Holds the log in a string, and can pretend to be corrupt or absent.
class FakeLogPersistence implements LogPersistence {
  /// Starts holding [text]; null means "no file yet".
  FakeLogPersistence([this.text]);

  /// The stored payload.
  String? text;

  /// How many times [write] has been called.
  int writes = 0;

  @override
  Future<String?> read() async => text;

  @override
  Future<void> write(String data) async {
    text = data;
    writes++;
  }
}
