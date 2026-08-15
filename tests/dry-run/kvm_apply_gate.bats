#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "KVM firmware apply is simulated in dry-run" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/modules/virtualization/22_firmware_uefi_tpm.sh'
    CURRENT_SCOPE=KVM
    DRY_RUN=true
    REAL_MACHINE_APPROVED=false
    LOG_FILE=/dev/null
    kvm_firmware_apply
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN would execute"* ]]
}

@test "KVM firmware apply is blocked when real gate is closed" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/modules/virtualization/22_firmware_uefi_tpm.sh'
    CURRENT_SCOPE=KVM
    DRY_RUN=false
    REAL_MACHINE_APPROVED=false
    LOG_FILE=/dev/null
    kvm_firmware_apply
  "
  [ "$status" -eq 5 ]
  [[ "$output" == *"SECURITY_BLOCK"* ]]
}
