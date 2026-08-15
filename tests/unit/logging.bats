#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "$REPO_ROOT/lib/common.sh"
  source "$REPO_ROOT/lib/logging.sh"
  TMPDIR_TEST="$(mktemp -d)"
  LOG_ROOT="$TMPDIR_TEST/logs"
  RUN_ID='logging-test'
  UWC_NOW='2026-08-14T12:00:00-04:00'
  safe_mkdir "$LOG_ROOT"
  log_init
}

teardown() { rm -rf "$TMPDIR_TEST"; }

@test "logger redacts common secret assignments" {
  log_info HOST 'TOKEN=abc123 PASSWORD=hunter2 normal=value'
  run cat "$MAIN_LOG"
  [ "$status" -eq 0 ]
  [[ "$output" != *'abc123'* ]]
  [[ "$output" != *'hunter2'* ]]
  [[ "$output" == *'***REDACTED***'* ]]
}
