#!/usr/bin/env bash

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

uw_now() {
  if [[ -n "${UWC_NOW:-}" ]]; then
    printf '%s\n' "$UWC_NOW"
  else
    date --iso-8601=seconds
  fi
}

uw_run_id() {
  if [[ -n "${UWC_RUN_ID:-}" ]]; then
    printf '%s\n' "$UWC_RUN_ID"
    return 0
  fi
  printf '%s_%s_%04x\n' "$(date +%Y%m%dT%H%M%S%z)" "${USER:-unknown}" "$((RANDOM % 65536))"
}

require_command() {
  command -v "$1" >/dev/null 2>&1
}

safe_mkdir() {
  mkdir -p -- "$1"
}
