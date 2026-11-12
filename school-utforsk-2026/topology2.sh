#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/config2.sh"
redis() { redis-cli --raw -h "$REDIS_HOST" -p "$REDIS_PORT" "$@"; }
[[ "$(redis ping)" == PONG ]] || { echo "Redis is not ready" >&2; exit 1; }
endpoint() {
  local key="daq_service:topology:endpoint:$1:$2"
  # Replace only this endpoint so old fixed addresses/methods do not survive.
  redis -n "$DAQSERVICE_DB" del "$key" >/dev/null
  redis -n "$DAQSERVICE_DB" hset "$key" "${@:3}" >/dev/null
}
# Remove the replay source link when switching to live acquisition.
redis -n "$DAQSERVICE_DB" del 'daq_service:topology:link:STFBFilePlayer:out,TimeFrameBuilder:in' >/dev/null
endpoint AmQStrTdcSampler out type push method bind enable-uds false
endpoint STFBuilder in type pull method connect enable-uds false
endpoint STFBuilder out type push method connect autoSubChannel true enable-uds false
redis -n "$DAQSERVICE_DB" set 'daq_service:topology:link:AmQStrTdcSampler:out,STFBuilder:in' none >/dev/null
redis -n "$DAQSERVICE_DB" set 'daq_service:topology:link:STFBuilder:out,TimeFrameBuilder:in' none >/dev/null
endpoint TimeFrameBuilder in type pull method bind enable-uds false
endpoint TimeFrameBuilder out type push method connect autoSubChannel true enable-uds false
endpoint FileSink in type pull method bind enable-uds false
# The pinned FileSink sends a DQM copy even without a monitor subscriber.
endpoint FileSink dqm type pub method bind waitForPeerConnection false enable-uds false
redis -n "$DAQSERVICE_DB" set 'daq_service:topology:link:TimeFrameBuilder:out,FileSink:in' none >/dev/null
echo "Topology loaded: AmQStrTdcSampler -> STFBuilder -> TimeFrameBuilder -> FileSink (dynamic bind ports)"
