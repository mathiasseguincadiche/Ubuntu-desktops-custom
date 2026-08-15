#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "$REPO_ROOT/lib/constants.sh"
  source "$REPO_ROOT/lib/common.sh"
  source "$REPO_ROOT/lib/locks.sh"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  lock_release || true
  rm -rf "$TMPDIR_TEST"
}

@test "lock can be acquired and released" {
  lock_acquire "$TMPDIR_TEST/engine.lock" 0
  [ -n "${UWC_LOCK_FD:-}" ]
  lock_release
  [ -z "${UWC_LOCK_FD:-}" ]
}
