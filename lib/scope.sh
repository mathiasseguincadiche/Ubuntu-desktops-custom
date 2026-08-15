#!/usr/bin/env bash

scope_valid() {
  case "$1" in
    HOST|KVM|VM_DEVOPS|BACKUP) return 0 ;;
    *) return 1 ;;
  esac
}

assert_scope() {
  local requested="$1" active="${2:-${ACTIVE_SCOPE:-}}"
  scope_valid "$requested" || return "$EXIT_INVALID_ARGUMENT"
  if [[ -n "$active" && "$active" != "$requested" ]]; then
    log_error ENGINE "scope violation active=$active requested=$requested"
    return "$EXIT_SECURITY_BLOCK"
  fi
}
