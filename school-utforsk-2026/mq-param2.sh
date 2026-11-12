#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/config2.sh"
redis() { redis-cli --raw -h "$REDIS_HOST" -p "$REDIS_PORT" "$@"; }
[[ "$(redis ping)" == PONG ]] || { echo "Redis is not ready" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)"
param() { redis -n "$PARAMETER_DB" hset "parameters:$1" "${@:2}" >/dev/null; }
[[ "$TDC_TYPE" =~ ^[1-9][0-9]*$ ]] || { echo 'TDC_TYPE must be a positive integer.' >&2; exit 1; }
[[ "$MAX_HBF" =~ ^[1-9][0-9]*$ ]] || { echo 'MAX_HBF must be a positive integer.' >&2; exit 1; }
param AmQStrTdcSampler-0 msiTcpIp "$AMANEQ_IP" TdcType "$TDC_TYPE" enable-uds false
param STFBuilder-0 max-hbf "$MAX_HBF" discard-output false enable-uds false
param TimeFrameBuilder-0 decimation-factor "$TFB_DECIMATION_FACTOR" discard-output false enable-uds false
param FileSink-0 multipart true merge-message true prefix "$OUTPUT_DIR" openmode create file-extension .dat enable-uds false
echo "Parameters loaded; FileSink output: $OUTPUT_DIR"
