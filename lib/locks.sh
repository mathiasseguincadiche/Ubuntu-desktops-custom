#!/usr/bin/env bash

lock_acquire() {
  local lock_file="$1"
  local wait_seconds="${2:-0}"
  safe_mkdir "$(dirname "$lock_file")"
  exec {UWC_LOCK_FD}>"$lock_file"
  if ! flock -w "$wait_seconds" "$UWC_LOCK_FD"; then
    eval "exec ${UWC_LOCK_FD}>&-"
    unset UWC_LOCK_FD
    return "$EXIT_DEPENDENCY_FAILED"
  fi
  UWC_LOCK_FILE="$lock_file"
}

lock_release() {
  if [[ -n "${UWC_LOCK_FD:-}" ]]; then
    flock -u "$UWC_LOCK_FD" || true
    eval "exec ${UWC_LOCK_FD}>&-"
    unset UWC_LOCK_FD UWC_LOCK_FILE
  fi
}
