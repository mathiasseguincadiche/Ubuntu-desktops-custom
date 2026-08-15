#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "HOST OS update apply is simulated in dry-run" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/modules/host/01_os_updates.sh'
    CURRENT_SCOPE=HOST
    DRY_RUN=true
    REAL_MACHINE_APPROVED=false
    LOG_FILE=/dev/null
    host_os_updates_apply
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would execute"* ]]
}

@test "HOST OS update apply is blocked when dry-run is off and real gate is closed" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/modules/host/01_os_updates.sh'
    CURRENT_SCOPE=HOST
    DRY_RUN=false
    REAL_MACHINE_APPROVED=false
    LOG_FILE=/dev/null
    host_os_updates_apply
  "
  [ "$status" -eq 5 ]
  [[ "$output" == *"SECURITY_BLOCK"* ]]
}

@test "firmware and graphics applies are routed through secure mutating runner" {
  grep -F 'run_mutating HOST' "$REPO_ROOT/modules/host/02_firmware_microcode.sh"
  grep -F 'run_mutating HOST' "$REPO_ROOT/modules/host/03_graphics_intel_arc.sh"
}
