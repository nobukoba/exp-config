#!/usr/bin/env bash
set -euo pipefail
nestdaq_load_config() {
  local config="${1:-${NESTDAQ_CONFIG:-}}"
  [[ -n "$config" && -r "$config" ]] || { echo "NestDAQ config not found: ${config:-<unset>}" >&2; return 2; }
  source "$config"
  : "${SPADI_ROOT:=/opt/spadi}"; : "${SPADI_LOCAL:=/workspace/spadi}"
  : "${REDIS_HOST:=127.0.0.1}"; : "${REDIS_PORT:=6379}"
  : "${DAQSERVICE_DB:=0}"; : "${METRICS_DB:=1}"; : "${PARAMETER_DB:=2}"
  : "${NESTDAQ_HOST_IP:=127.0.0.1}"; : "${TMUX_SOCKET:=spadi}"
}
nestdaq_cli() {
  command redis-cli "$@"
}
