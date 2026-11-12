#!/usr/bin/env bash
# Redis 6.0.10 has no redis-cli -e. Detect server errors explicitly.
redis() {
  local reply
  reply="$(redis-cli --raw -h "$REDIS_HOST" -p "$REDIS_PORT" "$@")" || return
  if [[ "$reply" =~ ^(ERR|WRONGTYPE|NOAUTH|NOPERM|READONLY|OOM|MISCONF|BUSY|LOADING|MASTERDOWN|CLUSTERDOWN|CROSSSLOT|EXECABORT)([[:space:]]|$) ]]; then
    echo "Redis command failed: $reply" >&2
    return 1
  fi
  printf '%s\n' "$reply"
}
