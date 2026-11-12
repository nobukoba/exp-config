#!/usr/bin/env bash
# Live acquisition defaults; override through the environment.
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
: "${OUTPUT_DIR:=${HERE}/output-live}"
: "${TFB_DECIMATION_FACTOR:=0}"
source "${HERE}/config.sh"
: "${AMANEQ_IP:=192.168.10.16}"
# 1 = LR-TDC, as in spadi-containers-second-trial's recipe for this board.
: "${TDC_TYPE:=1}"
: "${MAX_HBF:=4}"
