#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export NESTDAQ_CONFIG="${NESTDAQ_CONFIG:-${HERE}/config.sh}"
source "$NESTDAQ_CONFIG"
device="$1"; id="$2"
# Keep the last output visible even if startup fails.
tmux set-option -w -t "$TMUX_PANE" remain-on-exit on
tmux set-option -w -t "$TMUX_PANE" automatic-rename off
mkdir -p "$LOG_DIR"
# Let daq_service assign its instance ID and register the presence key.
# The window/log name remains stable; with no other instances, IDs are -0/-1/-2.
# FairMQ must know channel names before InitWrapper constructs fChannels.
# Redis still supplies dynamic addresses and links through daq_service.
channels=()
case "$device" in
  AmQStrTdcSampler) channels=(name=out,type=push,method=bind,address=unspecified) ;;
  STFBuilder) channels=(name=in,type=pull,method=connect,address=unspecified name=out,type=push,method=connect,address=unspecified) ;;
  STFBFilePlayer) channels=(name=out,type=push,method=connect,address=unspecified) ;;
  TimeFrameBuilder) channels=(name=in,type=pull,method=bind,address=unspecified name=out,type=push,method=connect,address=unspecified) ;;
  FileSink) channels=(name=in,type=pull,method=bind,address=unspecified name=dqm,type=pub,method=bind,address=unspecified) ;;
  *) echo "Unknown device: $device" >&2; exit 2 ;;
esac
bash "${HERE}/start-device.sh" "$device" --startup-state idle --channel-config "${channels[@]}" 2>&1 | tee "${LOG_DIR}/${id}.log"
