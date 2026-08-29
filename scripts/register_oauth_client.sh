#!/bin/bash

# ============================================================================
# Walks the one step that cannot be automated -- registering this app's Android
# OAuth client -- and runs everything around it that can be.
#
# Why a human has to click: an OAuth client is a credential, and Google exposes
# no create API for one. `gcloud` has no command, the Firebase CLI has no
# command, and the console is the only path. Everything either side of that
# click is done here.
#
# Until it is done, Connect fails with UNREGISTERED_ON_API_CONSOLE, which
# Android's Credential Manager surfaces as the far less helpful
# "canceled: account reauth failed" -- so the symptom names the account when
# the cause is the console.
#
# What this does for you:
#   * derives the SHA-1 from the real keystore, so the value pasted into the
#     console cannot be a stale copy of one;
#   * opens the console and puts each field on the clipboard in form order;
#   * verifies on the phone afterwards by reading the tile back, which asks
#     the keystore rather than trusting a local flag.
#
# Usage:
#   scripts/register_oauth_client.sh              # register, then verify
#   scripts/register_oauth_client.sh --verify-only
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_DIR
readonly CONSOLE_URL="https://console.cloud.google.com/auth/clients?project=kuhy-syncs"
readonly PACKAGE="com.kuhy.restaurant_rater"
readonly DEVICE="23181JEGR08034"
readonly DUMP=/tmp/restaurant_rater_ui.xml

log() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
step() { printf '   %s\n' "$1"; }

# Copies to the clipboard when a tool is available; prints regardless, so this
# still works over ssh with no X display.
clip() {
    if command -v xclip >/dev/null 2>&1; then
        printf '%s' "$1" | xclip -selection clipboard 2>/dev/null || true
        printf '   \033[32m[copied]\033[0m %s\n' "$1"
    else
        printf '   %s\n' "$1"
    fi
}

pause() { read -rp "   ...press Enter when that field is filled " _; }

# Reads the release signing fingerprint out of the keystore itself.
#
# Derived rather than hardcoded: a fingerprint copied into a doc goes stale
# silently, and the failure it causes looks nothing like "wrong SHA-1".
release_sha1() {
    local properties="$REPO_DIR/android/key.properties"
    if [[ ! -f "$properties" ]]; then
        echo "error: $properties not found; cannot derive the SHA-1" >&2
        return 1
    fi
    local store password alias
    store="$(grep -E '^storeFile=' "$properties" | cut -d= -f2-)"
    password="$(grep -E '^storePassword=' "$properties" | cut -d= -f2-)"
    alias="$(grep -E '^keyAlias=' "$properties" | cut -d= -f2-)"
    [[ "$store" = /* ]] || store="$REPO_DIR/android/$store"
    keytool -list -v -keystore "$store" -alias "$alias" \
        -storepass "$password" 2>/dev/null |
        grep -E '^[[:space:]]*SHA1:' | head -1 | sed 's/.*SHA1: //' | tr -d ' \r'
}

# Dumps the current screen so nodes can be found by their text.
dump_ui() {
    adb -s "$DEVICE" shell uiautomator dump /sdcard/rr_ui.xml >/dev/null 2>&1
    adb -s "$DEVICE" pull /sdcard/rr_ui.xml "$DUMP" >/dev/null 2>&1
}

# Opens the app's Settings screen, refusing to tap if it is not foreground.
#
# The foreground check is not paranoia: a blind tap once landed in an unrelated
# app that happened to be on screen.
open_settings() {
    adb -s "$DEVICE" shell monkey -p "$PACKAGE" \
        -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 5
    local top
    top="$(adb -s "$DEVICE" shell dumpsys activity activities 2>/dev/null |
        grep -m1 topResumedActivity | grep -o 'com\.[a-z_.]*' | head -1)"
    if [[ "$top" != "$PACKAGE" ]]; then
        step "refusing to tap: foreground app is '$top', not $PACKAGE"
        return 1
    fi
    dump_ui
    local coords
    coords="$(python3 "$REPO_DIR/scripts/find_ui_node.py" "$DUMP" centre Settings 2>/dev/null || true)"
    if [[ -z "$coords" ]]; then
        step "could not find the Settings control"
        return 1
    fi
    local x y
    read -r x y <<<"$coords"
    adb -s "$DEVICE" shell input tap "$x" "$y" >/dev/null 2>&1
    sleep 3
    dump_ui
}

# Reads the tile back. It asks the keystore, so a revoked session shows as
# disconnected rather than as a stale "connected".
verify_on_phone() {
    log "Verifying on the phone"
    if ! adb devices | grep -q "^$DEVICE"; then
        step "phone not attached; reconnect it and rerun with --verify-only"
        return 1
    fi
    open_settings || return 1
    if python3 "$REPO_DIR/scripts/find_ui_node.py" "$DUMP" has "Sync connected"; then
        log "CONNECTED — this device holds a session."
        step "Now tap 'Sync now' and confirm it reports 'Synced.'"
        return 0
    fi
    log "NOT CONNECTED yet."
    step "In Settings, tap 'Connect Google account' and pick"
    step "321krzychu@gmail.com -- the uid the database rules pin. Any other"
    step "account signs in fine and is then denied every read and write."
    step "Then rerun: scripts/register_oauth_client.sh --verify-only"
    return 1
}

main() {
    if [[ "${1:-}" == "--verify-only" ]]; then
        verify_on_phone
        return
    fi

    local sha1
    sha1="$(release_sha1)"
    if [[ -z "$sha1" ]]; then
        echo "error: could not read a SHA-1 from the keystore" >&2
        exit 1
    fi

    log "Register ONE Android OAuth client in project kuhy-syncs"
    step "Google has no API for this. One form, three fields."
    step "This app has no product flavors, so unlike punchme it needs only one."
    printf '\n'

    if command -v xdg-open >/dev/null 2>&1; then
        step "Opening the console..."
        xdg-open "$CONSOLE_URL" >/dev/null 2>&1 &
    else
        step "$CONSOLE_URL"
    fi
    sleep 2

    step "Click '+ CREATE CLIENT', set Application type = Android."
    printf '\n'
    step "Field 'Name':"
    clip "restaurant-rater"
    pause
    step "Field 'Package name':"
    clip "$PACKAGE"
    pause
    step "Field 'SHA-1 certificate fingerprint':"
    clip "$sha1"
    pause
    step "Click CREATE."
    pause

    log "Done in the console. Do NOT touch the existing Web client."
    step "It is already the audience this app's tokens are minted for."

    printf '\n'
    read -rp "   Registration takes a minute to propagate. Enter to verify: " _
    verify_on_phone
}

main "$@"
