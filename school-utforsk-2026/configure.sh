#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/config.sh"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)"
redis() { redis-cli --raw -h "$REDIS_HOST" -p "$REDIS_PORT" "$@"; }
[[ "$(redis ping)" == PONG ]] || { echo 'Redis is not ready' >&2; exit 1; }
# Do not flush databases: preserve the externally managed web controller.
param() { redis -n "$PARAMETER_DB" hset "parameters:$1" "${@:2}" >/dev/null; }
endpoint() { redis -n "$DAQSERVICE_DB" hset "daq_service:topology:endpoint:$1:$2" "${@:3}" >/dev/null; }
for i in 0 1 2; do
  printf -v subdir '%02d' "$i"
  param "STFBFilePlayer-${i}" in-file "${RAWDATA_DIR}/${subdir}/run000020.dat"
done
param TimeFrameBuilder-0 decimation-factor "$TFB_DECIMATION_FACTOR" discard-output false enable-uds false
param FileSink-0 multipart true merge-message true prefix "$OUTPUT_DIR" openmode create file-extension .dat enable-uds false
endpoint STFBFilePlayer out type push method connect autoSubChannel true enable-uds false
endpoint TimeFrameBuilder in type pull method bind enable-uds false address "tcp://${STF_TO_TFB_HOST}:${STF_TO_TFB_PORT}"
endpoint TimeFrameBuilder out type push method bind enable-uds false address "tcp://${TFB_OUTPUT_HOST}:${TFB_OUTPUT_PORT}"
redis -n "$DAQSERVICE_DB" set 'daq_service:topology:link:STFBFilePlayer:out,TimeFrameBuilder:in' none >/dev/null
endpoint FileSink in type pull method connect autoSubChannel true enable-uds false
# The pinned FileSink sends a DQM copy even without a monitor subscriber.
endpoint FileSink dqm type pub method bind waitForPeerConnection false enable-uds false address "tcp://${TFB_OUTPUT_HOST}:${FILE_SINK_DQM_PORT}"
redis -n "$DAQSERVICE_DB" set 'daq_service:topology:link:TimeFrameBuilder:out,FileSink:in' none >/dev/null
echo "FileSink output directory: $OUTPUT_DIR (openmode=create)"
echo 'Replay parameters and topology configured.'
