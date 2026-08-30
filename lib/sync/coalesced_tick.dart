/// Collapsing a burst of writes into one sync run, plus one follow-up.
library;

/// Runs an action, and while it runs remembers that it must run again.
///
/// The sync push is triggered by every single store write. That was fine while
/// the largest thing the app did was a rating — three writes — but importing a
/// menu writes one record per dish, and a thirty-dish paste would otherwise
/// launch thirty overlapping full-log pushes at once, each carrying very
/// nearly the same bytes as the last.
///
/// Coalescing rather than debouncing, deliberately: a debounce delays the
/// first push by however long the window is, which would make a single rating
/// slower to leave the device for the benefit of a case that happens once a
/// visit. This starts immediately and only *collapses* what piles up behind
/// it, so the common path is unchanged and the burst costs two runs.
///
/// The trailing run is what makes it safe. Writes that land mid-flight are not
/// in the push already going out, so dropping them would leave the device
/// silently behind until something else happened to write.
///
/// **It terminates only because a settled sync writes nothing back.** The run
/// this drives ends in a store write, a store write fires the very change
/// stream that calls this, and the trailing run turns that into a loop with no
/// exit — one network round-trip per turn, for as long as the app is open. It
/// is `syncNow` skipping its write-back when the merge changed nothing that
/// makes the sequence finite. Anything added to the run that writes
/// unconditionally brings the loop back.
class CoalescedTick {
  /// Coalesces calls to [run].
  CoalescedTick(this.run);

  /// The action. Its errors are swallowed, as the caller's were: a failed
  /// push is not an error the user has to dismiss, and it must not cancel the
  /// follow-up run that the writes behind it are waiting for.
  final Future<void> Function() run;

  bool _running = false;
  bool _again = false;

  /// Whether a run is in progress.
  bool get isRunning => _running;

  /// Runs now, or notes that a further run is owed and returns at once.
  Future<void> call() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        // Cleared *before* awaiting, so a write arriving during the run is
        // seen. Clearing it afterwards would swallow exactly the writes this
        // class exists to catch.
        _again = false;
        try {
          await run();
        } on Object catch (_) {
          // Fire-and-forget, as before.
        }
      } while (_again);
    } finally {
      _running = false;
    }
  }
}
