#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -f "$TASK_ROOT/tools/local-toolchain.env" ]; then . "$TASK_ROOT/tools/local-toolchain.env"; fi
if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
  JAVA_HOME=$(/usr/libexec/java_home -v 17); export JAVA_HOME
fi
if [ -n "${TODO_ANDROID_TOOLCHAIN:-}" ]; then
  GRADLE_BIN="$TODO_ANDROID_TOOLCHAIN/gradle-8.9/bin/gradle"
  ANDROID_HOME="$TODO_ANDROID_TOOLCHAIN/android-sdk"
  export GRADLE_USER_HOME="$TODO_ANDROID_TOOLCHAIN/gradle-home"
else
  GRADLE_BIN="${GRADLE_BIN:-gradle}"
  ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
fi
if [ -z "$ANDROID_HOME" ]; then printf 'Set ANDROID_HOME to your Android SDK directory (SDK 35 required).\n' >&2; exit 1; fi
export ANDROID_HOME
printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$TASK_ROOT/android/local.properties"
set -- -p "$TASK_ROOT/android" :app:assembleDebug --console plain
if [ "${ANDROID_USE_MIRROR:-0}" = 1 ]; then set -- "$@" --init-script "$TASK_ROOT/tools/mirrors.init.gradle"; fi
if [ "${ANDROID_OFFLINE:-0}" = 1 ]; then set -- "$@" --offline; fi
"$GRADLE_BIN" "$@"
mkdir -p "$TASK_ROOT/dist"
cp "$TASK_ROOT/android/app/build/outputs/apk/debug/app-debug.apk" "$TASK_ROOT/dist/desk-todo-debug.apk"
