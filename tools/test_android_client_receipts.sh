#!/bin/sh
# Host-only Java/HTTP regression. Requires JDK 17 and org.json 20240303 (no automatic downloads).
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -f "$TASK_ROOT/tools/local-toolchain.env" ]; then . "$TASK_ROOT/tools/local-toolchain.env"; fi
if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
  JAVA_HOME=$(/usr/libexec/java_home -v 17); export JAVA_HOME
fi
JAVAC_BIN="${JAVA_HOME:+$JAVA_HOME/bin/}javac"
JAVA_BIN="${JAVA_HOME:+$JAVA_HOME/bin/}java"
RECEIPT_JSON_JAR=${1:-${JSON_JAR:-}}
if [ -z "$RECEIPT_JSON_JAR" ]; then
  for cache in "${GRADLE_USER_HOME:-$HOME/.gradle}/caches" "${TODO_ANDROID_TOOLCHAIN:-$TASK_ROOT/tools}/gradle-home/caches"; do
    if [ -d "$cache" ]; then
      RECEIPT_JSON_JAR=$(find "$cache" -path '*/org.json/json/20240303/*/json-20240303.jar' -type f -print -quit)
      if [ -n "$RECEIPT_JSON_JAR" ]; then break; fi
    fi
  done
fi
if [ -z "$RECEIPT_JSON_JAR" ] || [ ! -f "$RECEIPT_JSON_JAR" ]; then
  printf 'Provide org.json 20240303: sh tools/test_android_client_receipts.sh /absolute/path/json-20240303.jar\nNo dependency is downloaded by this test.\n' >&2
  exit 1
fi
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mojian-android-receipts.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
SOURCES="$TASK_ROOT/android/app/src/main/java/com/desktodo/app"
"$JAVAC_BIN" -cp "$RECEIPT_JSON_JAR" -d "$TEST_DIR" "$TASK_ROOT/tests/android/ClientReceiptHostChecks.java" "$SOURCES/DeskApi.java" "$SOURCES/SyncPolicy.java" "$SOURCES/ScreenSync.java" "$SOURCES/CommitReceipt.java"
"$JAVA_BIN" -cp "$RECEIPT_JSON_JAR:$TEST_DIR" com.desktodo.app.ClientReceiptHostChecks
