#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export NESTDAQ_CONFIG="${HERE}/config2.sh"
source "$NESTDAQ_CONFIG"
[[ -n "${TMUX:-}" ]] || { echo 'Run this script inside tmux: tmux new-session -s school' >&2; exit 1; }
for cmd in tmux redis-cli AmQStrTdcSampler STFBuilder TimeFrameBuilder FileSink flock; do
  command -v "$cmd" >/dev/null || { echo "Command not found: $cmd" >&2; exit 1; }
done
session="$(tmux display-message -p '#{session_id}')"
windows=(FileSink-0 TimeFrameBuilder-0 STFBuilder-0 AmQStrTdcSampler-0)
mkdir -p "$LOG_DIR"
exec 9>"${LOG_DIR}/run.lock"
flock -n 9 || { echo 'Another run.sh is starting.' >&2; exit 1; }
existing="$(tmux list-windows -t "$session" -F '#{window_name}')"
for name in "${windows[@]}" STFBFilePlayer-0 STFBFilePlayer-1 STFBFilePlayer-2; do
  if [[ $'
'"$existing"$'
' == *$'
'"$name"$'
'* ]]; then
    echo "Window already exists: $name. End devices and close old replay windows first." >&2
    exit 1
  fi
done
bash "${HERE}/mq-param2.sh"
bash "${HERE}/topology2.sh"
# Pass effective configuration explicitly: a tmux server may have an older environment.
env_args=()
for name in NESTDAQ_CONFIG AMANEQ_IP TDC_TYPE MAX_HBF REDIS_HOST REDIS_PORT DAQSERVICE_DB METRICS_DB PARAMETER_DB NESTDAQ_HOST_IP NESTDAQ_SEVERITY RAWDATA_DIR LOG_DIR OUTPUT_DIR TFB_DECIMATION_FACTOR PATH LD_LIBRARY_PATH SPADI_ROOT SPADI_LOCAL NESTDAQ_PLUGIN_LIBDIR; do
  [[ -v "$name" ]] && env_args+=(-e "$name=${!name}")
done
for id in "${windows[@]}"; do
  device="${id%-*}"
  printf -v command 'exec bash %q %q %q' "${HERE}/device-window.sh" "$device" "$id"
  tmux new-window -d -t "${session}:" -n "$id" -c "$HERE" "${env_args[@]}" "$command" 9>&-
done
echo "Live source: ${AMANEQ_IP}, TDC_TYPE=${TDC_TYPE}; output: ${OUTPUT_DIR}"
echo 'Created four live-acquisition device windows in the current tmux session.'
echo 'Select all four devices in web-ctrl: Init Device and Connection -> Init Task -> Run.'
echo 'To finish: Stop -> Reset Task -> Reset Device -> End. Logs remain in each window and logs/.'
