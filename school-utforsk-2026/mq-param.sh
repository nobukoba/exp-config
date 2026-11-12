#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/config.sh"
redis() { redis-cli --raw -h "$REDIS_HOST" -p "$REDIS_PORT" "$@"; }
[[ "$(redis ping)" == PONG ]] || { echo "Redis is not ready" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)"
param() { redis -n "$PARAMETER_DB" hset "parameters:$1" "${@:2}" >/dev/null; }
for i in 0 1 2; do
  printf -v subdir '%02d' "$i"
  param "STFBFilePlayer-${i}" in-file "${RAWDATA_DIR}/${subdir}/run000020.dat"
done
param TimeFrameBuilder-0 decimation-factor "$TFB_DECIMATION_FACTOR" discard-output false enable-uds false
param FileSink-0 multipart true merge-message true prefix "$OUTPUT_DIR" openmode create file-extension .dat enable-uds false
echo "Parameters loaded; FileSink output: $OUTPUT_DIR"
