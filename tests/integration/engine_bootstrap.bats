#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() { rm -rf "$TMPDIR_TEST"; }

@test "engine bootstrap creates runtime state only in configured test roots" {
  export REPO_ROOT
  export LOG_ROOT="$TMPDIR_TEST/logs"
  export STATE_ROOT="$TMPDIR_TEST/state"
  export REPORT_ROOT="$TMPDIR_TEST/reports"
  export RUN_ID='integration-run'
  export UWC_NOW='2026-08-14T12:00:00-04:00'
  source "$REPO_ROOT/lib/bootstrap.sh"
  engine_bootstrap
  [ -f "$LOG_ROOT/$RUN_ID/main.log" ]
  [ -f "$STATE_ROOT/runs/$RUN_ID/run.json" ]
  [ -d "$REPORT_ROOT" ]
  [ "${REAL_MACHINE_APPROVED}" = 'false' ]
}
