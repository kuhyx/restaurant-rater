/// Rebuilding a screen whenever the data underneath it changes.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:restaurant_rater/data/rater_repository.dart';
import 'package:restaurant_rater/models/rater_snapshot.dart';

/// Rebuilds [builder] with a fresh snapshot after every change.
///
/// A change is any write — this device's, or a peer's merged in by a sync tick
/// while the screen is open. Both arrive on the same stream, so a rating made
/// on the other phone appears here without a pull-to-refresh, and without the
/// screen needing to know sync exists.
///
/// Reads synchronously rather than through a `StreamBuilder` with an initial
/// future: the snapshot is already in memory, so awaiting it would flash an
/// empty list on every single build.
class RaterScope extends StatefulWidget {
  /// Creates a scope over [repository].
  const RaterScope({
    required this.repository,
    required this.builder,
    super.key,
  });

  /// The data being watched.
  final RaterRepository repository;

  /// Builds the screen body from the current snapshot.
  final Widget Function(BuildContext context, RaterSnapshot snapshot) builder;

  @override
  State<RaterScope> createState() => _RaterScopeState();
}

class _RaterScopeState extends State<RaterScope> {
  StreamSubscription<void>? _subscription;
  late RaterSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.snapshot();
    _subscription = widget.repository.changes.listen(_refresh);
  }

  @override
  void dispose() {
    // Unsubscribing matters here: the store outlives every screen, so a
    // subscription left behind would keep calling setState on a disposed
    // State for the rest of the process.
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }

  void _refresh(void _) {
    if (!mounted) return;
    setState(() => _snapshot = widget.repository.snapshot());
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _snapshot);
}
