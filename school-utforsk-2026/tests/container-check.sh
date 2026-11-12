#!/usr/bin/env bash
# Run inside a SPADI DAQ container. Uses a private Redis and tmux session.
# Live devices are initialized, but never RUN: no FEE connection is attempted.
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/utforsk-check.XXXXXX)"
export REDIS_PORT="${TEST_REDIS_PORT:-16380}"
export REDIS_HOST=127.0.0.1 DAQSERVICE_DB=0 METRICS_DB=1 PARAMETER_DB=2
export LOG_DIR="${TEST_DIR}/logs" OUTPUT_DIR="${TEST_DIR}/output"
export NESTDAQ_SEVERITY=info
session="utforsk-check-$$"
cleanup() {
  tmux kill-session -t "$session" 2>/dev/null || true
  [[ ! -f "${TEST_DIR}/redis.pid" ]] || kill "$(cat "${TEST_DIR}/redis.pid")" 2>/dev/null || true
  echo "Test logs retained: $TEST_DIR"
}
trap cleanup EXIT
# Fail if the test port is already occupied; never operate on another Redis.
if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1; then
  echo "Test Redis port $REDIS_PORT is already in use." >&2; exit 1
fi
redis-server --bind 127.0.0.1 --port "$REDIS_PORT" --save '' --appendonly no \
  --loadmodule /opt/spadi/lib/redistimeseries.so \
  --daemonize yes --pidfile "${TEST_DIR}/redis.pid" --logfile "${TEST_DIR}/redis.log"
redis() { redis-cli --raw -h "$REDIS_HOST" -p "$REDIS_PORT" "$@"; }
change() {
  local transition="$1"; shift
  local list='' service
  for service in "$@"; do list+="${list:+,}\"${service}\""; done
  redis publish daqctl "{\"command\":\"change_state\",\"value\":\"$transition\",\"services\":[$list],\"instances\":[\"all\"]}" >/dev/null
}
wait_state() {
  local expected="$1"; shift
  local deadline=$((SECONDS+30)) ready service state
  while ((SECONDS<deadline)); do
    ready=true
    for service in "$@"; do
      state="$(redis get "daq_service:${service}:${service}-0:fair-mq-state")"
      [[ "$state" == "$expected" ]] || ready=false
      [[ "$state" != ERROR ]] || { echo "$service ERROR" >&2; return 1; }
    done
    if "$ready"; then return 0; fi
    sleep 0.2
  done
  echo "Timeout: expected $expected for $*" >&2
  for service in "$@"; do tail -n 12 "${LOG_DIR}/${service}-0.log" >&2 || true; done
  return 1
}
launch() {
  local script="$1" command
  rm -f "${TEST_DIR}/start.status"
  tmux new-session -d -s "$session" -n control 'sleep infinity'
  printf -v command 'REDIS_PORT=%q LOG_DIR=%q OUTPUT_DIR=%q NESTDAQ_SEVERITY=info bash %q >%q 2>&1; echo $? >%q; sleep infinity' \
    "$REDIS_PORT" "$LOG_DIR" "$OUTPUT_DIR" "${HERE}/${script}" "${TEST_DIR}/start.log" "${TEST_DIR}/start.status"
  tmux new-window -d -t "$session" -n launcher "$command"
  local deadline=$((SECONDS+35))
  while [[ ! -f "${TEST_DIR}/start.status" ]] && ((SECONDS<deadline)); do sleep 0.2; done
  [[ -f "${TEST_DIR}/start.status" && "$(cat "${TEST_DIR}/start.status")" == 0 ]] || { cat "${TEST_DIR}/start.log" >&2; return 1; }
}
# Actual live binaries and plugins, including dynamic port resolution.
live=(FileSink TimeFrameBuilder STFBuilder AmQStrTdcSampler)
redis set run_info:run_number 900001 >/dev/null
launch run2.sh
wait_state IDLE "${live[@]}"
# Check active-registry rejection before any parameters can change.
if (source "${HERE}/config2.sh"; source "${HERE}/startup-check.sh"; check_registry_idle); then
  echo 'Active registry was not rejected.' >&2; exit 1
fi
change CONNECT "${live[@]}"
wait_state 'DEVICE READY' "${live[@]}"
change 'INIT TASK' "${live[@]}"
wait_state READY "${live[@]}"
echo 'PASS: live IDLE -> DEVICE READY -> READY without accessing FEE'
for transition in 'RESET TASK' 'RESET DEVICE'; do
  change "$transition" "${live[@]}"
  if [[ "$transition" == 'RESET TASK' ]]; then wait_state 'DEVICE READY' "${live[@]}"; else wait_state IDLE "${live[@]}"; fi
done
change END "${live[@]}"
sleep 2
tmux kill-session -t "$session"
# Replay real raw data through real TFB and FileSink, exercising disk output.
LOG_DIR="${TEST_DIR}/replay-logs"; OUTPUT_DIR="${TEST_DIR}/replay-output"
replay=(FileSink TimeFrameBuilder STFBFilePlayer)
redis set run_info:run_number 900002 >/dev/null
launch run.sh
change CONNECT "${replay[@]}"
wait_state 'DEVICE READY' "${replay[@]}"
change 'INIT TASK' "${replay[@]}"
wait_state READY "${replay[@]}"
for service in "${replay[@]}"; do change RUN "$service"; done
sleep 5
# Stop sources first, leaving downstream consumers running to drain queues.
change STOP STFBFilePlayer; sleep 1
change STOP TimeFrameBuilder; wait_state READY TimeFrameBuilder
sleep 1
change STOP FileSink; wait_state READY FileSink
file="${OUTPUT_DIR}/run900002.dat"
[[ -s "$file" ]] || { echo "No FileSink output: $file" >&2; exit 1; }
# A data file must contain STF data, not only FileSink header/trailer.
python3 "${HERE}/tests/validate-output.py" "$file"
echo "PASS: replay -> TimeFrameBuilder -> FileSink saved $(stat -c %s "$file") bytes"
echo 'Live hardware RUN remains untested; TCP/24 and UDP/4660 require the board network.'
