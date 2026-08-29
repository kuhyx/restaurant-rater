# restaurant-rater

An Android app for rating restaurant dishes. A restaurant holds a menu in the
order you typed it; tapping the restaurant tells you which dish to eat next,
and rating it captures **smak / zapach / estetyka on 0–10** — the same three
axes and the same scale already used in longhand notes — plus optional
macronutrients, a photo, a note, and the price in zł.

## The pick rule

Tapping a restaurant does not re-roll. It **commits** a dish and remembers it:

1. If a dish is already committed and still on the menu, you get that dish
   again — across a re-tap, a force-stop, or a cold start at the table.
2. Otherwise the lowest-ordered dish you have not rated yet.
3. If every unrated dish has been skipped, the one skipped longest ago. A skip
   deprioritises; it never removes.
4. Once the whole menu is rated, round two: the dish you have gone longest
   without eating.

**Skip** is for a dish that is sold out or not what you feel like. It does not
count as rated. With only one unrated dish left, Skip is disabled rather than
pretending to do something.

Menu order is a per-item `orderKey` taken from the sync clock at creation and
never renumbered. That is what makes "the order you typed them" survive two
devices adding dishes offline: an integer index would collide, and deleting a
dish would renumber every dish after it.

A skip is a timestamp rather than a counter, for the same class of reason.
The log merges last-writer-wins, so two devices each skipping a dish would
converge on a count of 1 instead of 2 and silently lose one. A timestamp
merges correctly and says more: it re-offers the longest-ago refusal first.

## Photos do not sync

Ratings, menus, prices, macros and notes sync across devices. **Photo files do
not.** The sync transport is a Firebase RTDB JSON tree, which is not sized for
image blobs; base64-ing a photo into a record would inflate every push for
every device. Only the filename crosses the wire.

So a dish photographed on the phone shows its photo on the phone. Viewed on
another enrolled device, the same rating shows every score, macro and note
intact, with the image slot reading **"Photo is on another device"** — not a
broken image, and not silence.

## Layout

```
lib/models/   plain immutable value types
lib/logic/    pure functions: the pick rule, scores, ordering, stats
lib/data/     the repository boundary
lib/sync/     CRDT record codecs, the Firebase transport, bootstrap
lib/photos/   on-device photo storage
lib/ui/       one widget per file, grouped by screen
```

`test/` mirrors `lib/` one file for one file. There is deliberately no local
`theme.dart`: theming comes from the shared `design_system` package, so this
app cannot drift off the common token table.

Two structural notes worth knowing before editing `lib/sync/`:

* **`LogStore.upsert` replaces a record, it does not merge into one.** Merging
  happens at sync time. Every write in `CrdtRaterRepository` therefore goes
  through `_upsertMerged`, which carries the stored record's other fields
  forward at their original clocks. A write that names only the field its
  intent touches will otherwise delete every field it does not mention — that
  bug reached the phone once and made every restaurant vanish the moment a
  pick was committed.
* **A codec deliberately does not write every field it can read.**
  `restaurantToRecord` never writes `pending` and `menuItemToRecord` never
  writes `skippedAt`; only the pick and skip methods own those. That is what
  stops a rename from stamping a stale value over a peer's fresh one.

## Commands

```bash
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
dart format --set-exit-if-changed lib/ test/
flutter test --coverage
bash scripts/ci_mirror.sh          # everything CI runs, from a clean tree
scripts/install_hooks.sh           # once, after cloning
```

The bar is **100% line coverage**. `scripts/ci_mirror.sh` enforces it and also
checks that every file under `lib/` actually appears in the report — a file no
test imports is absent from lcov rather than reported at 0%, so a percentage
gate alone would fail open.

## Deploying to the phone

```bash
~/.claude/scripts/phone_deploy.sh ~/restaurant-rater --release
```

Never `adb uninstall` or `pm clear` — `install -r` preserves the data.

There is deliberately **no `.phone-deploy-flavor`** file: this app declares no
product flavors, so the artefact is `app-release.apk` and `phone_deploy.sh`
correctly omits `--flavor` when the file is absent. `.versioncode-offset` is
`0` and should stay there; it is a recovery valve, not a knob.

## Sync setup (one manual step)

Sync signs in with Google. An Android OAuth client is keyed to *package name +
signing SHA-1*, and Google exposes no API to create one — `gcloud` has no
command and neither does the Firebase CLI. So this package needs its own
client registered by hand, once:

```bash
scripts/register_oauth_client.sh          # opens the console, feeds each field
scripts/register_oauth_client.sh --verify-only
```

The script derives the SHA-1 from the keystore rather than from a note, opens
the right console page, and puts each field on the clipboard in form order, so
nothing has to be retyped. Afterwards it reads the tile back off the device,
which asks the keystore rather than trusting a local flag.

**Until that is done, Connect fails** — and the symptom is misleading. Android
reports `canceled: account reauth failed`, which names the account, while
`adb logcat` shows the real cause:

```
Auth.Api.Credentials: colz: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].
```

When picking the account, pick **321krzychu@gmail.com**. The database rules
pin that uid; any other account signs in fine and is then denied every read
and write, so the data layer looks broken while the auth layer looks perfect.

## Focus mode

`com.kuhy.restaurant_rater` is listed in the `~/phone-focus-mode` day
whitelists. The `com.kuhy` prefix already covers it, so the listing is
inventory rather than enforcement — but an app outside both would be hidden on
launch and look exactly like a crash.
