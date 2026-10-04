# CLAUDE.md — restaurant-rater

Android Flutter app (3.47.5, pinned in `.fvmrc`) for rating restaurant dishes.
Remote: `github.com/kuhyx/restaurant-rater`. Code in `lib/`, tests mirror it
under `test/`. Read `README.md` for the product; CI and the
pre-push mirror are `scripts/ci_mirror.sh`.

## Commands

- run: `flutter run`
- test: `flutter test --reporter=compact`
- test-changed: `scripts/test_changed.sh`
- lint: `flutter analyze --fatal-infos --fatal-warnings`
- coverage: `flutter test --coverage --reporter=compact`
- coverage-gaps: `coverage-gaps coverage/lcov.info`
