#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export NESTDAQ_CONFIG="${HERE}/config.sh"
source "$NESTDAQ_CONFIG"
for cmd in redis-cli STFBFilePlayer TimeFrameBuilder flock sha256sum; do
  command -v "$cmd" >/dev/null || { echo "Command not found: $cmd (run inside the SPADI DAQ container)" >&2; exit 1; }
done
mkdir -p "$LOG_DIR"
exec 9>"${LOG_DIR}/run.lock"
flock -n 9 || { echo 'This replay is already running.' >&2; exit 1; }
for i in 00 01 02; do
  [[ -s "${RAWDATA_DIR}/${i}/run000020.dat" ]] || { echo "Missing raw data: ${RAWDATA_DIR}/${i}/run000020.dat" >&2; exit 1; }
done
if [[ "$RAWDATA_DIR" == "${HERE}/rawdata" ]]; then
  (cd "$HERE" && sha256sum --check SHA256SUMS)
fi
bash "${HERE}/configure.sh"
pids=()
cleanup() {
  trap '' INT TERM
  if ((${#pids[@]})); then
    kill -TERM "${pids[@]}" 2>/dev/null || true
    # Bound shutdown even if a device is waiting for a disconnected peer.
    for ((attempt=0;attempt<50;attempt++)); do
      alive=false
      for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null && alive=true; done
      "$alive" || break
      sleep 0.1
    done
    kill -KILL "${pids[@]}" 2>/dev/null || true
    wait "${pids[@]}" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
launch() {
  local device="$1" id="$2"
  bash "${HERE}/start-device.sh" "$device" --id "$id" --startup-state idle >"${LOG_DIR}/${id}.log" 2>&1 9>&- &
  pids+=("$!")
  echo "Started ${id}: PID $!, log ${LOG_DIR}/${id}.log"
}
launch TimeFrameBuilder TimeFrameBuilder-0
for i in 0 1 2; do launch STFBFilePlayer "STFBFilePlayer-${i}"; done
echo 'Use web-ctrl: Init Device and Connection -> Init Task -> Run.'
echo 'Stop -> Reset Task -> Reset Device -> End in web-ctrl; Ctrl+C here stops all devices.'
status=0
wait -n "${pids[@]}" || status=$?
echo "A replay process exited (status ${status}); stopping remaining devices." >&2
exit "$status"
