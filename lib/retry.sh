#!/usr/bin/env bash

retry() {
  local attempts="$1" delay="$2"
  shift 2
  local n=1 rc=0

  [[ "$attempts" =~ ^[1-9][0-9]*$ ]] || return "$EXIT_INVALID_ARGUMENT"
  while (( n <= attempts )); do
    if "$@"; then
      return 0
    else
      rc=$?
    fi
    (( n == attempts )) && break
    sleep "$delay"
    ((n++))
  done
  return "$rc"
}
