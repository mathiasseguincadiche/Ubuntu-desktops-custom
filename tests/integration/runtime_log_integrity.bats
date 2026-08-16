#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  TEST_ROOT="$(mktemp -d)"
  export LOG_ROOT="$TEST_ROOT/logs"
  export RUN_ID='runtime-log-integrity-test'
  export DRY_RUN=true
  export REAL_MACHINE_APPROVED=false

  source "$REPO_ROOT/lib/constants.sh"
  source "$REPO_ROOT/lib/common.sh"
  source "$REPO_ROOT/lib/logging.sh"
  log_init
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "pre-APPLY recreates a vanished runtime log directory before first mutation" {
  rm -rf "$LOG_DIR"
  [ ! -d "$LOG_DIR" ]

  run log_recover_runtime_paths_preapply 'simulated operator confirmation window loss'
  [ "$status" -eq 0 ]
  [ -d "$LOG_DIR" ]
  [ -f "$MAIN_LOG" ]
  [ -f "$COMMAND_LOG" ]
  [ -f "$MODULE_LOG" ]
  grep -Fq 'runtime log paths recovered before first mutation' "$MAIN_LOG"
  grep -Fq 'simulated operator confirmation window loss' "$MAIN_LOG"
}

@test "REAL APPLY never recreates vanished audit logs after runtime approval" {
  export DRY_RUN=false
  export REAL_MACHINE_APPROVED=true
  rm -rf "$LOG_DIR"

  run log_recover_runtime_paths_preapply 'simulated post-approval loss'
  [ "$status" -eq "$EXIT_SECURITY_BLOCK" ]
  [ ! -d "$LOG_DIR" ]
  [[ "$output" == *'refusing to continue'* ]]
}

@test "runtime log integrity helper fails closed when audit files are unavailable" {
  rm -f "$MODULE_LOG"

  run log_require_runtime_paths
  [ "$status" -eq "$EXIT_SECURITY_BLOCK" ]
  [[ "$output" == *'runtime log integrity check failed'* ]]
}

@test "runtime gate repairs logs before setting REAL_MACHINE_APPROVED" {
  gate="$REPO_ROOT/lib/apply_gate.sh"
  recovery_line="$(grep -nF "log_recover_runtime_paths_preapply 'runtime log directory disappeared during final gate confirmation'" "$gate" | cut -d: -f1)"
  dryrun_line="$(grep -nF 'export DRY_RUN=false' "$gate" | cut -d: -f1)"
  approved_line="$(grep -nF 'export REAL_MACHINE_APPROVED=true' "$gate" | cut -d: -f1)"

  [ -n "$recovery_line" ]
  [ -n "$dryrun_line" ]
  [ -n "$approved_line" ]
  [ "$recovery_line" -lt "$dryrun_line" ]
  [ "$dryrun_line" -lt "$approved_line" ]
}
