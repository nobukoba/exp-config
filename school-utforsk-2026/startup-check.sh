#!/usr/bin/env bash
# Sourced after config.sh/config2.sh. Do not change or clear other DAQ state.
source "${HERE}/redis-common.sh"
registry() { redis -n "$DAQSERVICE_DB" "$@"; }
check_registry_idle() {
  [[ "$(registry ping)" == PONG ]] || { echo 'Redis is not ready.' >&2; return 1; }
  local ts_command active
  ts_command="$(redis -n "$METRICS_DB" command info TS.ADD)"
  [[ -n "$ts_command" ]] || {
    echo 'RedisTimeSeries is required by TimeFrameBuilder (TS.ADD is unavailable). Start Redis with redistimeseries.so loaded.' >&2
    return 1
  }
  active="$(registry --scan --pattern 'daq_service:*:presence')"
  [[ -z "$active" ]] || {
    echo 'DAQ devices are already registered in this Redis DB. End them before switching configurations.' >&2
    return 1
  }
}
wait_for_devices() {
  local deadline=$((SECONDS + ${STARTUP_TIMEOUT:-30})) id state ready
  while (( SECONDS < deadline )); do
    ready=true
    for id in "$@"; do
      state="$(registry get "daq_service:${id%-*}:${id}:fair-mq-state")"
      if [[ "$state" == ERROR ]]; then
        echo "$id failed; inspect its tmux window and ${LOG_DIR}/${id}.log" >&2
        return 1
      fi
      [[ "$state" == IDLE ]] || ready=false
    done
    if "$ready"; then echo 'All device instances registered and IDLE.'; return 0; fi
    sleep 0.2
  done
  echo "Devices did not become IDLE within ${STARTUP_TIMEOUT:-30}s. Inspect the retained tmux windows and logs/." >&2
  return 1
}
