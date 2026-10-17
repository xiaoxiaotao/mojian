#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$TASK_ROOT/dist/墨间.app/Contents/MacOS/MoJian"
if [ ! -x "$APP" ]; then printf 'Build the Mac application with tools/build_macos.sh first.\n' >&2; exit 1; fi
"$APP" --self-test
"$APP" --reliability-test
"$APP" --information-test "${TMPDIR:-/tmp}/mojian-test-previews"
"$APP" --task-management-test
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mojian-protocol.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
for name in differential_transfer refresh_plan paged_plane static_accent; do
  "${CXX:-c++}" -std=c++17 "$TASK_ROOT/tests/${name}_test.cpp" -o "$TEST_DIR/$name"
  "$TEST_DIR/$name"
done
printf 'PASS: native app and C++ protocol tests; no live model/device writes\n'
