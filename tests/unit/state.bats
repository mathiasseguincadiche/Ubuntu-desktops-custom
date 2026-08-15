#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "$REPO_ROOT/lib/constants.sh"
  source "$REPO_ROOT/lib/common.sh"
  source "$REPO_ROOT/lib/state.sh"
  STATE_ROOT="$(mktemp -d)"
  RUN_ID='unit-run'
  UWC_NOW='2026-08-14T12:00:00-04:00'
  state_init
}

teardown() { rm -rf "$STATE_ROOT"; }

@test "state engine persists and reads module state" {
  state_set '20_preflight_kvm' SUCCESS 'all good'
  run state_get '20_preflight_kvm'
  [ "$status" -eq 0 ]
  [ "$output" = 'SUCCESS' ]
}

@test "state engine rejects unknown states" {
  run state_set module INVALID_STATE
  [ "$status" -eq "$EXIT_INVALID_ARGUMENT" ]
}

@test "resume selects latest run" {
  RUN_ID='different'
  RUN_STATE_DIR=''
  state_resume_latest
  [ "$RUN_ID" = 'unit-run' ]
  [ -d "$RUN_STATE_DIR" ]
}
