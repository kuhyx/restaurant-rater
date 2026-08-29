/// Deciding which photo files no tasting refers to any more. Pure.
library;

/// Files present [onDisk] that no live tasting [referenced].
///
/// Pure and set-shaped so the decision to delete is testable without a file
/// system — the sweep that acts on it is three lines and does no thinking.
Set<String> orphanPhotos({
  required Set<String> onDisk,
  required Set<String> referenced,
}) => onDisk.difference(referenced);

/// Whether it is safe to sweep at all.
///
/// **This is the guard that stops the app deleting every photo you own.**
///
/// `LogStore.load()` deliberately returns an *empty* log for a missing or
/// truncated file rather than throwing, so a half-written save cannot brick
/// the app. That is the right call for the log — and catastrophic for a sweep
/// downstream of it, because an empty log references no photos, so every
/// single file on disk would look like an orphan and be deleted, permanently,
/// for a fault that the next successful sync would otherwise have repaired.
///
/// So the sweep only runs when the log has something in it. The cost of
/// skipping is a few stale files; the cost of not skipping is every photo.
bool canSweep({required bool logIsEmpty}) => !logIsEmpty;
