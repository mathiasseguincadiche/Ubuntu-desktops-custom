#!/usr/bin/env bash

lock_acquire() {
  local lock_file="$1"
  local wait_seconds="${2:-0}"
  safe_mkdir "$(dirname "$lock_file")"

  exec 9>"$lock_file"
  if ! flock -w "$wait_seconds" 9; then
    exec 9>&-
    return "$EXIT_DEPENDENCY_FAILED"
  fi
  UWC_LOCK_FD=9
  UWC_LOCK_FILE="$lock_file"
}

lock_release() {
  if [[ "${UWC_LOCK_FD:-}" == '9' ]]; then
    flock -u 9 || true
    exec 9>&-
    unset UWC_LOCK_FD UWC_LOCK_FILE
  fi
}
