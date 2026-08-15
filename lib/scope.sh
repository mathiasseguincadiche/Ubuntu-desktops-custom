#!/usr/bin/env bash

scope_valid() {
  case "$1" in
    HOST|KVM|VM_DEVOPS|BACKUP) return 0 ;;
    *) return 1 ;;
  esac
}

assert_scope() {
  local requested="$1"
  scope_valid "$requested" || return "$EXIT_INVALID_ARGUMENT"
  if [[ -n "${ACTIVE_SCOPE:-}" && "$ACTIVE_SCOPE" != "$requested" ]]; then
    log_error ENGINE "scope violation active=$ACTIVE_SCOPE requested=$requested"
    return "$EXIT_SECURITY_BLOCK"
  fi
}
