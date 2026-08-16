#!/usr/bin/env bash

log_init() {
  : "${LOG_ROOT:?LOG_ROOT must be set}"
  : "${RUN_ID:?RUN_ID must be set}"
  LOG_DIR="$LOG_ROOT/$RUN_ID"
  safe_mkdir "$LOG_DIR"
  MAIN_LOG="$LOG_DIR/main.log"
  COMMAND_LOG="$LOG_DIR/commands.log"
  MODULE_LOG="$LOG_DIR/modules.log"
  : > "$MAIN_LOG"
  : > "$COMMAND_LOG"
  : > "$MODULE_LOG"
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
  message="$(redact_text "$@")"
  line="$(uw_now) $level $scope $message"

  if [[ -n "${MAIN_LOG:-}" ]]; then
    printf '%s\n' "$line" >> "$MAIN_LOG"
  fi

  # Unit libraries and legacy callers may source logging.sh without ui.sh.
  # Preserve the historical console behavior in that isolated context.
  if ! declare -F ui_is_operator >/dev/null 2>&1; then
    printf '%s\n' "$line"
    return 0
  fi

  if [[ "${UI_MODE_CURRENT:-operator}" == technical ]]; then
    printf '%s\n' "$line"
    return 0
  fi

  case "$level" in
    WARN) ui_warn "$scope — $message" ;;
    ERROR) ui_error "$scope — $message" ;;
    *) : ;;
  esac
}

log_info() {
  local scope="${1:-ENGINE}"
  (( $# > 0 )) && shift
  _log INFO "$scope" "$@"
}

log_ok() {
  local scope="${1:-ENGINE}"
  (( $# > 0 )) && shift
  _log OK "$scope" "$@"
}

log_warn() {
  local scope="${1:-ENGINE}"
  (( $# > 0 )) && shift
  _log WARN "$scope" "$@"
}

log_error() {
  local scope="${1:-ENGINE}"
  (( $# > 0 )) && shift
  _log ERROR "$scope" "$@" >&2
}

log_command() {
  local scope="$1"
  shift
  local line
  line="$(uw_now) COMMAND $scope $(redact_text "$@")"
  if [[ -n "${COMMAND_LOG:-}" ]]; then
    printf '%s\n' "$line" >> "$COMMAND_LOG"
  fi
}

log_module_boundary() {
  local id="$1" phase="$2" state="$3"
  [[ -n "${MODULE_LOG:-}" ]] || return 0
  printf '\n===== %s | module=%s | phase=%s | %s =====\n' "$(uw_now)" "$id" "$phase" "$state" >> "$MODULE_LOG"
}
