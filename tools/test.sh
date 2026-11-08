#!/bin/sh
set -eu
python3 "$(dirname -- "$0")/generate_preset_catalog.py" --check
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$TASK_ROOT/dist/墨间.app/Contents/MacOS/MoJian"
if [ ! -x "$APP" ]; then printf 'Build the Mac application with tools/build_macos.sh first.\n' >&2; exit 1; fi
"$APP" --self-test
"$APP" --repeat-test
"$APP" --extension-test
"$APP" --reliability-test
"$APP" --readability-test "${TMPDIR:-/tmp}/mojian-readability-previews"
"$APP" --information-test "${TMPDIR:-/tmp}/mojian-test-previews"
"$APP" --task-management-test
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mojian-protocol.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
for name in differential_transfer refresh_plan paged_plane static_accent autonomy_geometry provision_frames weather_dns weather_body network_recovery display_guard frame_borrow paint_transaction commit_policy gx_full_settings; do
  "${CXX:-c++}" -std=c++17 "$TASK_ROOT/tests/${name}_test.cpp" -o "$TEST_DIR/$name"
  "$TEST_DIR/$name"
done
"${CXX:-c++}" -std=c++17 -I"$TASK_ROOT/tests/display_stubs" -I"$TASK_ROOT/firmware/src" \
  "$TASK_ROOT/tests/display_shutdown_test.cpp" "$TASK_ROOT/firmware/src/EPD.cpp" "$TASK_ROOT/firmware/src/EPD_SPI.cpp" -o "$TEST_DIR/display_shutdown"
"${CXX:-c++}" -std=c++17 -DMOJIAN_EXPERIMENT_BW_SLEEP=1 -I"$TASK_ROOT/tests/display_stubs" -I"$TASK_ROOT/firmware/src" \
  "$TASK_ROOT/tests/display_shutdown_test.cpp" "$TASK_ROOT/firmware/src/EPD.cpp" "$TASK_ROOT/firmware/src/EPD_SPI.cpp" -o "$TEST_DIR/display_shutdown_ab"
"$TEST_DIR/display_shutdown_ab"
"$TEST_DIR/display_shutdown"
for variant in production sleep init gx_full_temp gx_full_cdi; do
  case "$variant" in
    production) experiment_flag="" ;;
    sleep) experiment_flag="-DMOJIAN_EXPERIMENT_BW_SLEEP=1" ;;
    init) experiment_flag="-DMOJIAN_EXPERIMENT_BW_INIT=1" ;;
    gx_full_temp) experiment_flag="-DMOJIAN_EXPERIMENT_GX_FULL_TEMP=1" ;;
    gx_full_cdi) experiment_flag="-DMOJIAN_EXPERIMENT_GX_FULL_CDI=1" ;;
  esac
  "${CXX:-c++}" -std=c++17 ${experiment_flag:+"$experiment_flag"} -I"$TASK_ROOT/tests/display_stubs" -I"$TASK_ROOT/firmware/src" \
    "$TASK_ROOT/tests/display_init_test.cpp" "$TASK_ROOT/firmware/src/EPD.cpp" "$TASK_ROOT/firmware/src/EPD_SPI.cpp" -o "$TEST_DIR/display_init_$variant"
  "$TEST_DIR/display_init_$variant"
done
python3 "$TASK_ROOT/tests/test_http_parser.py"
python3 "$TASK_ROOT/tests/test_upload_lifecycle.py"
python3 "$TASK_ROOT/tests/test_autonomy_dispatch.py"
python3 "$TASK_ROOT/tests/test_storage_safety.py"
python3 "$TASK_ROOT/tests/test_boot_mode.py"
python3 "$TASK_ROOT/tests/test_observe_display.py"
python3 "$TASK_ROOT/tests/test_gx_reference.py"
printf 'PASS: native app and C++ protocol tests; no live model/device writes\n'

"$TASK_ROOT/agent-engine/runtime/bin/node" "$TASK_ROOT/tests/phone_layout_test.mjs"
