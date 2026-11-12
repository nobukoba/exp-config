#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export NESTDAQ_CONFIG="${HERE}/config.sh"
source "$NESTDAQ_CONFIG"
[[ -n "${TMUX:-}" ]] || { echo 'Run this script inside tmux: tmux new-session -s school' >&2; exit 1; }
for cmd in tmux redis-cli STFBFilePlayer TimeFrameBuilder FileSink sha256sum flock; do
  command -v "$cmd" >/dev/null || { echo "Command not found: $cmd" >&2; exit 1; }
done
session="$(tmux display-message -p '#{session_id}')"
windows=(FileSink-0 TimeFrameBuilder-0 STFBFilePlayer-0 STFBFilePlayer-1 STFBFilePlayer-2)
mkdir -p "$LOG_DIR" "$OUTPUT_DIR"
LOG_DIR="$(cd -- "$LOG_DIR" && pwd)"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)"
exec 9>"${LOG_DIR}/run.lock"
flock -n 9 || { echo 'Another run.sh is starting.' >&2; exit 1; }
existing="$(tmux list-windows -t "$session" -F '#{window_name}')"
for name in "${windows[@]}"; do
  if [[ $'
'"$existing"$'
' == *$'
'"$name"$'
'* ]]; then
    echo "Window already exists: $name. End devices and close old replay windows first." >&2
    exit 1
  fi
done
for i in 00 01 02; do
  [[ -s "${RAWDATA_DIR}/${i}/run000020.dat" ]] || { echo "Missing raw data: ${RAWDATA_DIR}/${i}/run000020.dat" >&2; exit 1; }
done
if [[ "$RAWDATA_DIR" == "${HERE}/rawdata" ]]; then
  (cd "$HERE" && sha256sum --check SHA256SUMS)
fi
# Parameters use auto-assigned -0/-1/-2 IDs. Another running DAQ would
# change these IDs and could receive our configuration: reject it first.
source "${HERE}/startup-check.sh"
check_registry_idle
bash "${HERE}/mq-param.sh"
bash "${HERE}/topology.sh"
# Pass effective configuration explicitly: a tmux server may have an older environment.
env_args=()
for name in NESTDAQ_CONFIG REDIS_HOST REDIS_PORT DAQSERVICE_DB METRICS_DB PARAMETER_DB NESTDAQ_HOST_IP NESTDAQ_SEVERITY RAWDATA_DIR LOG_DIR OUTPUT_DIR TFB_DECIMATION_FACTOR PATH LD_LIBRARY_PATH SPADI_ROOT SPADI_LOCAL NESTDAQ_PLUGIN_LIBDIR; do
  [[ -v "$name" ]] && env_args+=(-e "$name=${!name}")
done
for id in "${windows[@]}"; do
  device="${id%-*}"
  printf -v command 'exec bash %q %q %q' "${HERE}/device-window.sh" "$device" "$id"
  tmux new-window -d -t "${session}:" -n "$id" -c "$HERE" "${env_args[@]}" "$command" 9>&-
done
wait_for_devices "${windows[@]}"

echo 'Created five device windows in the current tmux session.'
echo 'Select all five devices in web-ctrl: Init Device and Connection -> Init Task -> Run.'
echo 'To finish: Stop -> Reset Task -> Reset Device -> End. Logs remain in each window and logs/.'
