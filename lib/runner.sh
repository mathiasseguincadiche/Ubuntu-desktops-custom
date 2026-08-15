#!/usr/bin/env bash

_command_string() {
  local out='' arg
  for arg in "$@"; do
    printf -v out '%s%q ' "$out" "$arg"
  done
  printf '%s' "${out% }"
}

run_command() {
  local scope="$1" effect="$2"
  shift 2
  [[ "${1:-}" == '--' ]] && shift

  assert_scope "$scope" || return $?
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
  fi

  log_info "$scope" "execute: $rendered"
  "$@"
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
