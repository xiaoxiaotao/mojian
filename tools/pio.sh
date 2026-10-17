#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKSPACE_ROOT=$(CDPATH= cd -- "$TASK_ROOT/../.." && pwd)
if [ -x "$WORKSPACE_ROOT/.venv/bin/pio" ] && [ -f "$WORKSPACE_ROOT/common/README.md" ]; then
  export PLATFORMIO_CORE_DIR="${PLATFORMIO_CORE_DIR:-$WORKSPACE_ROOT/.platformio}"
  exec "$WORKSPACE_ROOT/.venv/bin/pio" "$@" -d "$TASK_ROOT/firmware"
fi
export PLATFORMIO_CORE_DIR="${PLATFORMIO_CORE_DIR:-$HOME/.platformio}"
exec "${PIO_BIN:-pio}" "$@" -d "$TASK_ROOT/firmware"
