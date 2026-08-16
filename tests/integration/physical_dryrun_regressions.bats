#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "KVM catalog precheck defers missing curl only during dry-run" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    assert_scope() { :; }
    log_info() { :; }
    command() {
      if [[ \"\$1\" == '-v' && \"\${2:-}\" == 'curl' ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    REPO_ROOT='$REPO_ROOT'
    DRY_RUN=true
    source '$REPO_ROOT/modules/virtualization/25_os_catalog.sh'
    kvm_catalog_precheck
  "
  [ "$status" -eq 0 ]

  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    assert_scope() { :; }
    log_info() { :; }
    command() {
      if [[ \"\$1\" == '-v' && \"\${2:-}\" == 'curl' ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    REPO_ROOT='$REPO_ROOT'
    DRY_RUN=false
    source '$REPO_ROOT/modules/virtualization/25_os_catalog.sh'
    kvm_catalog_precheck
  "
  [ "$status" -eq 3 ]
}

@test "dry-run failure reporting captures orchestrator status inside else branch" {
  run grep -A12 -F 'if orchestrator_run_all; then' "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'else\n    rc=$?'* ]]
  [[ "$output" == *"VERDICT: FULL DRY-RUN FAIL (rc=%d)"* ]]
  [[ "$output" == *'exit "$rc"'* ]]
}

@test "VM identity and cloud-init dry-run need no runtime SSH credentials" {
  run bash -c "
    set -Eeuo pipefail
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    assert_scope() { :; }
    log_info() { :; }
    run_mutating() { :; }
    REPO_ROOT='$REPO_ROOT'
    STATE_ROOT='$BATS_TEST_TMPDIR/state'
    mkdir -p \"\$STATE_ROOT\"
    VM_DEVOPS_NAME=ubuntu-devops
    VM_DEVOPS_ADDRESS_MODE=dhcp-reservation
    DRY_RUN=true
    unset VM_ADMIN_USER VM_ADMIN_SSH_PUBLIC_KEY_FILE
    source '$REPO_ROOT/modules/devops-vm/42_identity_ssh.sh'
    vm_identity_ssh_precheck
    vm_identity_ssh_apply
    vm_identity_ssh_postcheck
    source '$REPO_ROOT/modules/devops-vm/41_cloud_init.sh'
    vm_cloud_init_precheck
    vm_cloud_init_apply
    grep -Fqx 'VM_ADMIN_USER=dryrun-devops' \"\$STATE_ROOT/ubuntu-devops-vm-identity.env\"
    grep -Fq 'DRYRUN_PLACEHOLDER_KEY_NOT_USED' \"\$STATE_ROOT/ubuntu-devops-user-data.yaml\"
  "
  [ "$status" -eq 0 ]
}

@test "VM identity real execution still requires runtime SSH credentials" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    assert_scope() { :; }
    log_info() { :; }
    REPO_ROOT='$REPO_ROOT'
    STATE_ROOT='$BATS_TEST_TMPDIR/state-real'
    mkdir -p \"\$STATE_ROOT\"
    VM_DEVOPS_NAME=ubuntu-devops
    VM_DEVOPS_ADDRESS_MODE=dhcp-reservation
    DRY_RUN=false
    unset VM_ADMIN_USER VM_ADMIN_SSH_PUBLIC_KEY_FILE
    source '$REPO_ROOT/modules/devops-vm/42_identity_ssh.sh'
    vm_identity_ssh_precheck
  "
  [ "$status" -eq 10 ]
}
