#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/config-common.sh"; nestdaq_load_config "${NESTDAQ_CONFIG:-}"
[[ $# -ge 1 ]] || { echo "Usage: start-device.sh <device> [args...]" >&2; exit 2; }
device="$1"; shift; cmd="$(command -v "$device" || true)"; [[ -n "$cmd" ]] || { echo "Device not found: $device" >&2; exit 127; }
plugin_dir="${NESTDAQ_PLUGIN_LIBDIR:-}"
if [[ -z "$plugin_dir" ]]; then
  for candidate in "${SPADI_LOCAL}/lib" "${SPADI_LOCAL}/lib64" "${SPADI_ROOT}/lib" "${SPADI_ROOT}/lib64"; do
    [[ -d "$candidate" ]] || continue
    find "$candidate" -maxdepth 1 -type f -name '*daq_service*.so*' -print -quit | grep -q . && { plugin_dir="$candidate"; break; }
  done
fi
: "${plugin_dir:=${SPADI_ROOT}/lib}"
opts=(-S "<${plugin_dir}" -P daq_service -P metrics -P parameter_config --registry-uri "tcp://${REDIS_HOST}:${REDIS_PORT}/${DAQSERVICE_DB}" --metrics-uri "tcp://${REDIS_HOST}:${REDIS_PORT}/${METRICS_DB}" --parameter-config-uri "tcp://${REDIS_HOST}:${REDIS_PORT}/${PARAMETER_DB}" --host-ip "${NESTDAQ_HOST_IP}" --severity "${NESTDAQ_SEVERITY:-debug4}")
echo "+ $cmd $* ${opts[*]}"; exec "$cmd" "$@" "${opts[@]}"
