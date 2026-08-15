#!/usr/bin/env bash

log_init() {
  : "${LOG_ROOT:?LOG_ROOT must be set}"
  : "${RUN_ID:?RUN_ID must be set}"
  LOG_DIR="$LOG_ROOT/$RUN_ID"
  safe_mkdir "$LOG_DIR"
  MAIN_LOG="$LOG_DIR/main.log"
  COMMAND_LOG="$LOG_DIR/commands.log"
  : > "$MAIN_LOG"
  : > "$COMMAND_LOG"
}

redact_text() {
  local text="$*"
  text="$(printf '%s' "$text" | sed -E \
    -e 's/((PASSWORD|TOKEN|SECRET|AWS_SECRET_ACCESS_KEY|RESTIC_PASSWORD)=)[^[:space:]]+/\1***REDACTED***/Ig' \
    -e 's/(-----BEGIN [A-Z ]*PRIVATE KEY-----).*/\1 ***REDACTED***/Ig')"
  printf '%s' "$text"
}

_log() {
  local level="$1" scope="$2"
  shift 2
  local message line
  message="$(redact_text "$*")"
  line="$(uw_now) $level $scope $message"
  printf '%s\n' "$line"
  if [[ -n "${MAIN_LOG:-}" ]]; then
    printf '%s\n' "$line" >> "$MAIN_LOG"
  fi
}

log_info() { _log INFO "${1:-ENGINE}" "${*:2}"; }
log_ok() { _log OK "${1:-ENGINE}" "${*:2}"; }
log_warn() { _log WARN "${1:-ENGINE}" "${*:2}"; }
log_error() { _log ERROR "${1:-ENGINE}" "${*:2}" >&2; }

log_command() {
  local scope="$1"
  shift
  local line
  line="$(uw_now) COMMAND $scope $(redact_text "$*")"
  if [[ -n "${COMMAND_LOG:-}" ]]; then
    printf '%s\n' "$line" >> "$COMMAND_LOG"
  fi
}
