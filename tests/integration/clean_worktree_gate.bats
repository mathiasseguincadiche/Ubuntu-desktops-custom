#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  TEST_REPO="$BATS_TEST_TMPDIR/repo"
  git init -q "$TEST_REPO"
  git -C "$TEST_REPO" config user.email test@example.invalid
  git -C "$TEST_REPO" config user.name test
  printf '%s\n' canonical > "$TEST_REPO/tracked.sh"
  git -C "$TEST_REPO" add tracked.sh
  git -C "$TEST_REPO" commit -qm initial
}

run_gate() {
  bash -c "
    source '$PROJECT_ROOT/lib/constants.sh'
    source '$PROJECT_ROOT/lib/common.sh'
    log_error() { :; }
    source '$PROJECT_ROOT/lib/apply_gate.sh'
    REPO_ROOT='$TEST_REPO'
    REAL_APPLY_REQUIRE_CLEAN_WORKTREE=true
    $1
  "
}

@test "clean tracked worktree passes gate" {
  run run_gate 'apply_gate_require_clean_worktree'
  [ "$status" -eq 0 ]
}

@test "modified tracked file is security blocked" {
  printf '%s\n' modified >> "$TEST_REPO/tracked.sh"
  run run_gate 'apply_gate_require_clean_worktree'
  [ "$status" -eq 8 ]
}

@test "staged tracked change is security blocked" {
  printf '%s\n' staged >> "$TEST_REPO/tracked.sh"
  git -C "$TEST_REPO" add tracked.sh
  run run_gate 'apply_gate_require_clean_worktree'
  [ "$status" -eq 8 ]
}

@test "untracked runtime file does not dirty protected worktree" {
  printf '%s\n' runtime > "$TEST_REPO/runtime.log"
  run run_gate 'apply_gate_require_clean_worktree'
  [ "$status" -eq 0 ]
}

@test "dry-run proof cannot be written from dirty tracked code" {
  printf '%s\n' modified >> "$TEST_REPO/tracked.sh"
  run run_gate "RUN_ID=test-run; REAL_APPLY_DRYRUN_PROOF_FILE=state/full-dry-run.pass; apply_gate_write_dryrun_proof"
  [ "$status" -eq 8 ]
  [ ! -e "$TEST_REPO/state/full-dry-run.pass" ]
}

@test "dry-run proof records clean tracked worktree and becomes invalid after drift" {
  run run_gate "RUN_ID=test-run; REAL_APPLY_DRYRUN_PROOF_FILE=state/full-dry-run.pass; apply_gate_write_dryrun_proof"
  [ "$status" -eq 0 ]
  grep -Fqx 'worktree=clean_tracked' "$TEST_REPO/state/full-dry-run.pass"

  printf '%s\n' drift >> "$TEST_REPO/tracked.sh"
  run run_gate "REAL_APPLY_DRYRUN_PROOF_FILE=state/full-dry-run.pass; apply_gate_verify_dryrun_proof"
  [ "$status" -eq 8 ]
}
