/// How the three kinds of thing share one flat CRDT log.
library;

/// Prefix for a restaurant record.
const String kRestaurantPrefix = 'r:';

/// Prefix for a menu item record.
const String kMenuItemPrefix = 'm:';

/// Prefix for a tasting record.
const String kTastingPrefix = 't:';

/// Builds a record id from a kind [prefix] and a bare uuid.
///
/// Three record kinds live in one `Log`, so an id has to say which kind it is:
/// a decoder that guessed from the field names would misread a record written
/// by a newer build that added a field.
///
/// Foreign keys are stored *bare* inside a record's fields (a menu item's
/// `restaurant` field holds the uuid, not `r:<uuid>`) and prefixed only at
/// lookup, so exactly one place decides how a key is spelled.
String recordId(String prefix, String bareId) => '$prefix$bareId';

/// Returns the bare uuid when [id] has [prefix], or null when it does not.
///
/// Null rather than a throw: a record of another kind is not an error, it is
/// simply not this decoder's business, and every decoder walks the whole log.
String? bareId(String id, String prefix) =>
    id.startsWith(prefix) ? id.substring(prefix.length) : null;
