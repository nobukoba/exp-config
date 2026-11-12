#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export NESTDAQ_CONFIG="${HERE}/config.sh"
source "$NESTDAQ_CONFIG"
device="$1"; id="$2"
# Keep the last output visible even if startup fails.
tmux set-option -w -t "$TMUX_PANE" remain-on-exit on
tmux set-option -w -t "$TMUX_PANE" automatic-rename off
mkdir -p "$LOG_DIR"
bash "${HERE}/start-device.sh" "$device" --id "$id" --startup-state idle 2>&1 | tee "${LOG_DIR}/${id}.log"
