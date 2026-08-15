#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "--apply is rejected before real preflight while feature flag is false" {
  run bash "$REPO_ROOT/install.sh" --apply
  [ "$status" -eq 8 ]
  [[ "$output" == *"REAL APPLY BLOCKED: feature flag REAL_APPLY_FEATURE_ENABLED=false."* ]]
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
