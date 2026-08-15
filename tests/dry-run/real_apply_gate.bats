#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "execution candidate enables guarded real-apply feature" {
  grep -F 'REAL_APPLY_FEATURE_ENABLED=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_MACHINE_APPROVED=false' "$REPO_ROOT/config/virtualization.conf"
}

@test "--apply is rejected without interactive TTY before hardware preflight" {
  run bash "$REPO_ROOT/install.sh" --apply
  [ "$status" -eq 8 ]
  [[ "$output" == *'REAL APPLY BLOCKED: an interactive TTY is mandatory.'* ]]
}

@test "backup proof is tied to commit and maximum age" {
  grep -F 'REAL_APPLY_BACKUP_MAX_AGE_SECONDS=86400' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'recorded' "$REPO_ROOT/lib/apply_gate.sh"
  grep -F 'age=$((now - created))' "$REPO_ROOT/lib/apply_gate.sh"
}

@test "runtime gate is the only place that opens real approval" {
  run grep -R -n -E '^[[:space:]]*(export[[:space:]]+)?REAL_MACHINE_APPROVED=true' \
    "$REPO_ROOT" --include='*.sh' --exclude='apply_gate.sh'
  [ "$status" -ne 0 ]
  grep -F 'export REAL_MACHINE_APPROVED=true' "$REPO_ROOT/lib/apply_gate.sh"
}

@test "real apply still requires dry-run backup confirmation and phase gates" {
  grep -F 'REAL_APPLY_REQUIRE_CURRENT_COMMIT_DRY_RUN=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_APPLY_REQUIRE_VERIFIED_BACKUP=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_APPLY_REQUIRE_EXACT_CONFIRMATION=true' "$REPO_ROOT/config/apply-gate.conf"
  grep -F 'REAL_APPLY_PHASE_CONFIRMATION=true' "$REPO_ROOT/config/apply-gate.conf"
}
