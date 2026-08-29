/// Prices in Polish złoty, held as an integer number of grosz.
library;

/// Formats [grosz] for display, e.g. `2400` -> `24 zł`, `2450` -> `24,50 zł`.
///
/// Whole złoty drop the decimals, because that is how a menu prints them and
/// how the source notes were written (`tom kha z kurczakiem zupa 24 zł`).
/// A comma is the decimal separator, matching Polish convention.
String formatPln(int grosz) {
  final negative = grosz < 0;
  final absolute = grosz.abs();
  final zloty = absolute ~/ 100;
  final remainder = absolute % 100;
  final sign = negative ? '-' : '';
  if (remainder == 0) return '$sign$zloty zł';
  return '$sign$zloty,${remainder.toString().padLeft(2, '0')} zł';
}

/// Parses a hand-typed price into grosz, or null when [text] says no price.
///
/// Accepts every spelling that turns up when typing at a table: `24`,
/// `24,50`, `24.50`, `24 zł`, `24zl`, and any of those with stray spaces.
/// Blank input returns null — an unpriced dish is normal, not an error, and
/// the caller must not be forced to invent a zero.
///
/// Returns null rather than throwing on genuine nonsense. This parses a text
/// field the user is still typing into; a throw would have to be caught on
/// every keystroke.
int? parsePln(String text) {
  final cleaned = text
      .toLowerCase()
      .replaceAll('zł', '')
      .replaceAll('zl', '')
      .replaceAll(' ', '')
      .replaceAll(' ', '') // non-breaking space, common in pasted menus
      .replaceAll(',', '.');
  if (cleaned.isEmpty) return null;

  // Anchored, and with at most two decimals: `12.345` is far more likely a
  // mistyped price than a request to round, so it is rejected rather than
  // silently truncated to 12,34.
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;

  final zloty = int.parse(match.group(1)!);
  final fraction = match.group(2);
  if (fraction == null) return zloty * 100;
  // A single decimal digit is tenths: `24.5` is 24,50 rather than 24,05.
  final grosz = fraction.length == 1
      ? int.parse(fraction) * 10
      : int.parse(fraction);
  return zloty * 100 + grosz;
}
