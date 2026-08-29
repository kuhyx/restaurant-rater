#!/bin/bash

# ============================================================================
# CI mirror: reproduce what CI runs, locally, before push.
#
# `flutter clean` first, for the same reason the Python repos build a throwaway
# venv: a stale incremental build can hide a real failure, and a pre-push gate
# that only passes on an already-warm tree is not a gate.
#
# Three checks here have no equivalent in the sibling Flutter repos:
#   * the 100% line-coverage gate, which is this repo's hard bar;
#   * the completeness gate that keeps it honest, since a lib/ file no test
#     imports is missing from lcov.info entirely rather than reported at 0%;
#   * `flutter build apk --release`, the shipping artefact. This repo declares
#     no product flavors -- unlike punchme, whose daily/sandbox split forces a
#     `--flavor` on every build -- so the bare form is correct here and adding
#     one would fail looking for a variant that does not exist. Android-only,
#     so there is no web build to guard `dart:io` with, and no need for one:
#     dart:io is legal in lib/ here.
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR

log() { printf '==> %s\n' "$1"; }

# Echoes the path of the lcov report, or exits when the test run never made it.
coverage_report() {
    local file="$REPO_DIR/coverage/lcov.info"
    if [[ ! -f "$file" ]]; then
        echo "error: $file is missing; did the test run fail?" >&2
        exit 1
    fi
    echo "$file"
}

# Files under lib/ that legitimately never appear in lcov.info, each with the
# reason. A file no test imports is simply absent from the report, so the
# percentage gate below cannot see it — "100%" of a denominator that quietly
# excludes half the platform layer is a gate that fails open. Every absence has
# to be listed here, on purpose, or the build stops.
declare -rA COVERAGE_EXEMPT=(
    # Deliberately empty. An exemption is a suppression: main.dart is covered
    # by a real widget test that pumps the app root, not excluded. Adding an
    # entry here needs asking first.
)

# `flutter test --coverage` instruments lib/ only, which is why this walks lib/.
#
# Fails when a lib/ file is missing from the report without being exempt, and
# when an exemption has gone stale — an entry that is now covered, or names a
# file that no longer exists, is a lie the next reader would trust.
enforce_coverage_completeness() {
    local file
    file="$(coverage_report)"
    local status=0 path

    while IFS= read -r path; do
        if grep -qxF "SF:$path" "$file"; then
            continue
        fi
        if [[ -v "COVERAGE_EXEMPT[$path]" ]]; then
            echo "  exempt: $path — ${COVERAGE_EXEMPT[$path]}"
            continue
        fi
        echo "error: $path is in lib/ but absent from lcov.info: no test" \
            "imports it, so the coverage gate never sees it. Add a test, or" \
            "add it to COVERAGE_EXEMPT with the reason." >&2
        status=1
    done < <(find lib -name '*.dart' | sort)

    for path in "${!COVERAGE_EXEMPT[@]}"; do
        if [[ ! -f "$path" ]]; then
            echo "error: COVERAGE_EXEMPT lists $path, which does not exist" >&2
            status=1
        elif grep -qxF "SF:$path" "$file"; then
            echo "error: $path is covered now; drop its COVERAGE_EXEMPT entry" >&2
            status=1
        fi
    done

    return "$status"
}

# Lists "<file>:<line>" for every uncovered line, minus those the source marks
# with `// coverage:ignore-line`.
#
# lcov itself does not honour that marker -- it is a convention this gate
# implements, so an unreachable line is opted out *at the line*, in the source,
# next to its reason. That is far narrower than exempting a whole file, which
# is what would otherwise drop its covered lines out of the denominator too.
uncovered_lines() {
    local file
    file="$(coverage_report)"
    local source line
    while IFS= read -r entry; do
        source="${entry%%:*}"
        line="${entry##*:}"
        # The marker sits on the line itself or on any line directly above it,
        # so a multi-line justification comment still applies.
        local probe=$((line - 1)) marked=0
        if sed -n "${line}p" "$source" | grep -q 'coverage:ignore-line'; then
            marked=1
        fi
        while [[ $marked -eq 0 && $probe -gt 0 ]]; do
            local text
            text="$(sed -n "${probe}p" "$source")"
            if [[ "$text" =~ coverage:ignore-line ]]; then
                marked=1
                break
            fi
            # Keep walking only while we are still inside a comment block.
            [[ "$text" =~ ^[[:space:]]*// ]] || break
            probe=$((probe - 1))
        done
        [[ $marked -eq 1 ]] || echo "$entry"
    done < <(awk -F: '
        /^SF:/ { source = $2 }
        /^DA:/ { split($2, a, ","); if (a[2] == 0) print source ":" a[1] }
    ' "$file")
}

# Fails unless every line in the lcov report was hit, ignoring lines the source
# explicitly marks unreachable. Parsed from the DA records rather than
# lcov --summary so the check needs no extra tool on a CI runner.
enforce_full_coverage() {
    local file
    file="$(coverage_report)"
    local found hit missed
    found="$(awk -F: '/^LF:/{s+=$2} END{print s+0}' "$file")"
    hit="$(awk -F: '/^LH:/{s+=$2} END{print s+0}' "$file")"
    mapfile -t missed < <(uncovered_lines)
    echo "Lines covered: $hit / $found (${#missed[@]} unexplained)"
    if [[ ${#missed[@]} -gt 0 ]]; then
        printf 'error: uncovered line: %s\n' "${missed[@]}" >&2
        echo "Add a test, or mark it // coverage:ignore-line with a reason." >&2
        exit 1
    fi
}

main() {
    cd "$REPO_DIR"

    # CI has already run the individual steps by this point and only needs the
    # completeness check, whose exemption list lives here so that the local
    # gate and the remote one cannot disagree.
    if [[ "${1:-}" == "--coverage-completeness-only" ]]; then
        enforce_coverage_completeness
        return
    fi

    # Both coverage gates, for a CI job that has already run the test step.
    # CI calls this rather than reimplementing the check, so the definition of
    # "100%" -- including which lines are explicitly unreachable -- lives in
    # exactly one place.
    if [[ "${1:-}" == "--coverage-only" ]]; then
        enforce_coverage_completeness
        enforce_full_coverage
        return
    fi

    log "flutter clean"
    flutter clean

    log "flutter pub get"
    flutter pub get

    log "flutter analyze --fatal-infos --fatal-warnings"
    flutter analyze --fatal-infos --fatal-warnings

    log "dart format --set-exit-if-changed"
    dart format --set-exit-if-changed lib/ test/

    log "flutter test --coverage"
    flutter test --coverage

    log "coverage gate"
    enforce_coverage_completeness
    enforce_full_coverage

    # No `--flavor`: this repo declares no product flavors, so the artefact is
    # app-release.apk. CI runs the same line; a gate that builds differently is
    # not a gate.
    log "flutter build apk --release"
    flutter build apk --release

    echo "CI mirror passed."
}

main "$@"
