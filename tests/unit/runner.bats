#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "$REPO_ROOT/lib/constants.sh"
  source "$REPO_ROOT/lib/common.sh"
  source "$REPO_ROOT/lib/logging.sh"
  source "$REPO_ROOT/lib/scope.sh"
  source "$REPO_ROOT/lib/runner.sh"
  TMPDIR_TEST="$(mktemp -d)"
  LOG_ROOT="$TMPDIR_TEST/logs"
  RUN_ID='runner-test'
  safe_mkdir "$LOG_ROOT"
  log_init
  ACTIVE_SCOPE='HOST'
}

teardown() { rm -rf "$TMPDIR_TEST"; }

@test "mutating command is simulated in dry-run" {
  DRY_RUN=true
  REAL_MACHINE_APPROVED=false
  target="$TMPDIR_TEST/not-created"
  run run_mutating HOST touch "$target"
  [ "$status" -eq 0 ]
  [ ! -e "$target" ]
  [[ "$output" == *'DRY-RUN would execute'* ]]
}

@test "mutating command is security blocked when dry-run is disabled but gate is closed" {
  DRY_RUN=false
  REAL_MACHINE_APPROVED=false
  target="$TMPDIR_TEST/not-created"
  run run_mutating HOST touch "$target"
  [ "$status" -eq "$EXIT_SECURITY_BLOCK" ]
  [ ! -e "$target" ]
}

@test "readonly command can execute with closed real-machine gate" {
  DRY_RUN=false
  REAL_MACHINE_APPROVED=false
  run run_readonly HOST printf '%s' 'probe-ok'
  [ "$status" -eq 0 ]
  [[ "$output" == *'probe-ok'* ]]
}

@test "scope mismatch is blocked" {
  ACTIVE_SCOPE='KVM'
  run run_readonly HOST printf ok
  [ "$status" -eq "$EXIT_SECURITY_BLOCK" ]
}
