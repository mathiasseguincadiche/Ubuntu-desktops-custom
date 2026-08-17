#!/usr/bin/env bash

_command_string() {
  local out='' arg
  for arg in "$@"; do
    printf -v out '%s%q ' "$out" "$arg"
  done
  printf '%s' "${out% }"
}

run_command() {
  local scope="$1" effect="$2" rc live_action=false live_label='' watchdog_pid=''
  shift 2
  [[ "${1:-}" == '--' ]] && shift

  if assert_scope "$scope"; then
    :
  else
    rc=$?
    return "$rc"
  fi

  [[ "$effect" == "$EFFECT_READONLY" || "$effect" == "$EFFECT_MUTATING" ]] || return "$EXIT_INVALID_ARGUMENT"
  (( $# > 0 )) || return "$EXIT_INVALID_ARGUMENT"

  local rendered
  rendered="$(_command_string "$@")"
  log_command "$scope" "$rendered"

  if [[ "$effect" == "$EFFECT_MUTATING" ]]; then
    if is_true "${DRY_RUN:-true}"; then
      log_info "$scope" "DRY-RUN would execute: $rendered"
      return 0
    fi
    if ! is_true "${REAL_MACHINE_APPROVED:-false}"; then
      log_error "$scope" "SECURITY_BLOCK mutating command refused: $rendered"
      return "$EXIT_SECURITY_BLOCK"
    fi

    if declare -F ui_live_action_begin >/dev/null 2>&1 && ui_live_progress_enabled; then
      live_label="$(ui_live_action_label "$scope" "$rendered")"
      if [[ -n "$live_label" ]]; then
        ui_live_action_begin "$live_label"
        live_action=true
      fi
    fi

    # Keep the actual command in the foreground so sudo/TTY semantics stay
    # unchanged. A sidecar watchdog observes only its descendant process tree.
    if declare -F process_watchdog_start >/dev/null 2>&1; then
      process_watchdog_start "${BASHPID:-$$}" "$scope" "${live_label:-$rendered}"
      watchdog_pid="${PROCESS_WATCHDOG_PID:-}"
    fi
  fi

  log_info "$scope" "execute: $rendered"
  if "$@"; then
    rc=0
  else
    rc=$?
  fi

  if [[ -n "$watchdog_pid" ]] && declare -F process_watchdog_stop >/dev/null 2>&1; then
    process_watchdog_stop "$watchdog_pid"
  fi

  if [[ "$live_action" == true ]]; then
    if (( rc == 0 )); then
      ui_live_action_ok
    else
      ui_live_action_fail
    fi
  fi

  return "$rc"
}

run_readonly() {
  local scope="$1"
  shift
  run_command "$scope" "$EFFECT_READONLY" -- "$@"
}

run_mutating() {
  local scope="$1"
  shift
  run_command "$scope" "$EFFECT_MUTATING" -- "$@"
}

run_remote() {
  local scope="$1" effect="$2" host="$3"
  shift 3
  [[ "$scope" == "$SCOPE_VM_DEVOPS" ]] || return "$EXIT_SECURITY_BLOCK"
  run_command "$scope" "$effect" -- ssh -o BatchMode=yes -- "$host" "$@"
}
