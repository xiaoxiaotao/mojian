#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$TASK_ROOT/dist/墨间.app"
if [ ! -d "$TASK_ROOT/agent-engine/node_modules" ] || [ ! -x "$TASK_ROOT/agent-engine/runtime/bin/node" ]; then
  printf 'Prepare Agent dependencies: npm ci --prefix "%s/agent-engine" and python3 "%s/tools/prepare_agent_runtime.py"\n' "$TASK_ROOT" "$TASK_ROOT" >&2
  exit 1
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
python3 "$TASK_ROOT/tools/prepare_screen_fonts.py" --destination "$APP/Contents/Resources/Fonts"
if [ -n "${MACOS_SDK:-}" ]; then
  SDK_PATH="$MACOS_SDK"
elif [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk ]; then
  SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk
else
  SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
fi
swiftc -sdk "$SDK_PATH" -swift-version 5 -parse-as-library -O -target arm64-apple-macosx14.0 -framework SwiftUI -framework EventKit -framework AppKit -framework CoreBluetooth -framework Security -framework UserNotifications "$TASK_ROOT"/macos/Sources/*.swift -o "$APP/Contents/MacOS/MoJian"
cp "$TASK_ROOT/macos/Info.plist" "$APP/Contents/Info.plist"
cp "$TASK_ROOT"/macos/Resources/StaticAccent-*.png "$APP/Contents/Resources/"
if [ -f "$TASK_ROOT/macos/Resources/MoJian.icns" ]; then cp "$TASK_ROOT/macos/Resources/MoJian.icns" "$APP/Contents/Resources/"; fi
ENGINE="$TASK_ROOT/agent-engine"
if [ -f "$ENGINE/package-lock.json" ] && [ -x "$ENGINE/runtime/bin/node" ]; then
  mkdir -p "$APP/Contents/Resources/agent-engine"
  rsync -a --exclude '.DS_Store' --exclude 'composition-check.yml' --exclude '*.test.*' "$ENGINE/bridge.mjs" "$ENGINE/tools.mjs" "$ENGINE/mojian.patch.yml" "$ENGINE/package.json" "$ENGINE/package-lock.json" "$ENGINE/NODE-SOURCE.txt" "$ENGINE/node_modules" "$APP/Contents/Resources/agent-engine/"
  mkdir -p "$APP/Contents/Resources/agent-engine/runtime/bin"
  cp "$ENGINE/runtime/bin/node" "$APP/Contents/Resources/agent-engine/runtime/bin/node"
  cp "$ENGINE/runtime/LICENSE" "$APP/Contents/Resources/agent-engine/runtime/LICENSE"
fi
codesign --force --deep --sign - "$APP"
printf 'Built: %s\n' "$APP"
