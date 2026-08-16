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

log_runtime_paths_ready() {
  [[ -n "${LOG_DIR:-}" && -d "$LOG_DIR" ]] || return 1
  [[ -n "${MAIN_LOG:-}" && -f "$MAIN_LOG" && -w "$MAIN_LOG" ]] || return 1
  [[ -n "${COMMAND_LOG:-}" && -f "$COMMAND_LOG" && -w "$COMMAND_LOG" ]] || return 1
  [[ -n "${MODULE_LOG:-}" && -f "$MODULE_LOG" && -w "$MODULE_LOG" ]] || return 1
}

log_recover_runtime_paths_preapply() {
  local reason="${1:-runtime log paths missing before first mutation}"

  log_runtime_paths_ready && return 0

  # Recovery is allowed only while the process is still in the non-mutating
  # pre-APPLY state. Once REAL APPLY is open, loss of audit logs is fail-closed.
  if ! is_true "${DRY_RUN:-true}" || is_true "${REAL_MACHINE_APPROVED:-false}"; then
    printf 'ERROR: runtime log paths disappeared after REAL APPLY approval; refusing to continue.\n' >&2
    return "${EXIT_SECURITY_BLOCK:-8}"
  fi

  : "${LOG_DIR:?LOG_DIR must be set}"
  : "${MAIN_LOG:?MAIN_LOG must be set}"
  : "${COMMAND_LOG:?COMMAND_LOG must be set}"
  : "${MODULE_LOG:?MODULE_LOG must be set}"

  safe_mkdir "$LOG_DIR" || return "${EXIT_PRECHECK_FAILED:-3}"
  : >> "$MAIN_LOG" || return "${EXIT_PRECHECK_FAILED:-3}"
  : >> "$COMMAND_LOG" || return "${EXIT_PRECHECK_FAILED:-3}"
  : >> "$MODULE_LOG" || return "${EXIT_PRECHECK_FAILED:-3}"
  chmod u+rw "$MAIN_LOG" "$COMMAND_LOG" "$MODULE_LOG" 2>/dev/null || true

  printf '%s WARN ENGINE runtime log paths recovered before first mutation reason=%s\n' \
    "$(uw_now)" "$(redact_text "$reason")" >> "$MAIN_LOG"
  log_runtime_paths_ready
}

log_require_runtime_paths() {
  log_runtime_paths_ready && return 0
  printf 'ERROR: runtime log integrity check failed; audit logs are unavailable. REAL APPLY remains fail-closed.\n' >&2
  return "${EXIT_SECURITY_BLOCK:-8}"
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
    if [[ -d "${LOG_DIR:-}" ]]; then
      printf '%s\n' "$line" >> "$MAIN_LOG" || printf '%s\n' "$line" >&2
    else
      printf '%s\n' "$line" >&2
    fi
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
    if [[ -d "${LOG_DIR:-}" ]]; then
      printf '%s\n' "$line" >> "$COMMAND_LOG" || printf '%s\n' "$line" >&2
    else
      printf '%s\n' "$line" >&2
    fi
  fi
}

log_module_boundary() {
  local id="$1" phase="$2" state="$3"
  [[ -n "${MODULE_LOG:-}" ]] || return 0
  [[ -d "${LOG_DIR:-}" ]] || return "${EXIT_SECURITY_BLOCK:-8}"
  printf '\n===== %s | module=%s | phase=%s | %s =====\n' "$(uw_now)" "$id" "$phase" "$state" >> "$MODULE_LOG"
}
