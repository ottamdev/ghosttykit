#!/usr/bin/env bash
set -euo pipefail

# Builds dist/ottam-ghostty.tar.gz from the upstream commit in PIN plus
# patches/ottam.patch. Needs macOS on arm64, Xcode, and the Zig version in PIN.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=PIN
source "$ROOT_DIR/PIN"

WORK_DIR="$ROOT_DIR/.work"
SRC_DIR="$WORK_DIR/ghostty"
STAGE_DIR="$WORK_DIR/ottam-ghostty"
DIST_DIR="$ROOT_DIR/dist"

if [ "$(zig version)" != "$ZIG_VERSION" ]; then
  echo "Zig $ZIG_VERSION required, found $(zig version)" >&2
  exit 1
fi

# `xcrun -f metal` succeeds even when the tool itself is missing.
if ! xcrun metal --version >/dev/null 2>&1; then
  xcodebuild -downloadComponent MetalToolchain
fi

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$SRC_DIR" "$DIST_DIR" "$STAGE_DIR/resources/ghostty"

git -C "$SRC_DIR" init -q
git -C "$SRC_DIR" fetch -q --depth 1 https://github.com/ghostty-org/ghostty "$GHOSTTY_COMMIT"
git -C "$SRC_DIR" checkout -q FETCH_HEAD
git -C "$SRC_DIR" apply "$ROOT_DIR/patches/ottam.patch"

# sentry would write crashes into Ghostty.app's directory; i18n would link
# LGPL libintl.
(
  cd "$SRC_DIR"
  zig build \
    -Demit-xcframework=true \
    -Demit-macos-app=false \
    -Dxcframework-target=native \
    -Doptimize=ReleaseFast \
    -Dsentry=false \
    -Di18n=false
)

cp -R "$SRC_DIR/macos/GhosttyKit.xcframework" "$STAGE_DIR/"
cp -R "$SRC_DIR/zig-out/share/ghostty/themes" "$STAGE_DIR/resources/ghostty/themes"
cp -R "$SRC_DIR/zig-out/share/terminfo" "$STAGE_DIR/resources/terminfo"
cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/THIRD_PARTY.md" "$STAGE_DIR/"

LIBRARY="$STAGE_DIR/GhosttyKit.xcframework/macos-arm64/libghostty-internal.a"
fail() {
  echo "build.sh: $1" >&2
  exit 1
}

# Read these into files first: `grep -q` closes a pipe early, and under
# pipefail the writer's SIGPIPE would fail the check.
ar -t "$LIBRARY" > "$WORK_DIR/members.txt" || fail "cannot list $LIBRARY"
nm -gU "$LIBRARY" > "$WORK_DIR/symbols.txt" 2>/dev/null || fail "cannot read symbols of $LIBRARY"

test -f "$STAGE_DIR/resources/terminfo/78/xterm-ghostty" || fail "terminfo is missing"
test ! -e "$STAGE_DIR/resources/ghostty/shell-integration" || fail "shell-integration is present"
grep -q '_ghostty_surface_process_output$' "$WORK_DIR/symbols.txt" || fail "manual IO is not exported"
if grep -E -q '^(textdomain|dcigettext|bindtextdom)\.o$' "$WORK_DIR/members.txt"; then
  fail "libintl is linked into the library"
fi
if grep -q '_sentry_init$' "$WORK_DIR/symbols.txt"; then
  fail "sentry is linked into the library"
fi

COPYFILE_DISABLE=1 tar -C "$WORK_DIR" -czf "$DIST_DIR/ottam-ghostty.tar.gz" ottam-ghostty
(cd "$DIST_DIR" && shasum -a 256 ottam-ghostty.tar.gz | tee ottam-ghostty.tar.gz.sha256)
