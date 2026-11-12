#!/usr/bin/env bash
set -euo pipefail

# Stop only the device windows created by run.sh or run2.sh in this tmux session.
# Redis, web-ctrl and the user's other windows are intentionally untouched.
if [[ -z "${TMUX:-}" ]]; then
  echo "Run stop.sh inside the tmux session used for run.sh." >&2
  exit 1
fi
session="$(tmux display-message -p '#{session_id}')"
devices=(FileSink-0 TimeFrameBuilder-0 STFBFilePlayer-0 STFBFilePlayer-1 STFBFilePlayer-2 STFBuilder-0 AmQStrTdcSampler-0)
targets=()

# Match exact window names, and retain window IDs to avoid target ambiguity.
while IFS=' ' read -r id name; do
  for device in "${devices[@]}"; do
    if [[ "$name" == "$device" ]]; then
      targets+=("$id")
      break
    fi
  done
done < <(tmux list-windows -t "$session" -F '#{window_id} #{window_name}')

if (( ${#targets[@]} == 0 )); then
  echo "No UTFORSK device windows found in this tmux session."
  exit 0
fi

echo "Stopping ${#targets[@]} UTFORSK device window(s) (Redis and web-ctrl stay running)."
echo "Note: For a clean data-file close, use web-ctrl Stop first."
for id in "${targets[@]}"; do
  tmux send-keys -t "$id" C-c
done

# Give foreground pipelines a chance to exit before closing their windows.
sleep 2
for id in "${targets[@]}"; do
  if tmux list-windows -t "$session" -F '#{window_id}' | grep -Fxq -- "$id"; then
    tmux kill-window -t "$id"
  fi
done
echo "UTFORSK device windows closed. Redis, web-ctrl, and other windows were not touched."
