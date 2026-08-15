#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "custom NAT apply is fully simulated in dry-run" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/modules/virtualization/24_networks.sh'
    CURRENT_SCOPE=KVM
    DRY_RUN=true
    REAL_MACHINE_APPROVED=false
    REPO_ROOT='$REPO_ROOT'
    LIBVIRT_URI='qemu:///system'
    KVM_NETWORK_NAME='devops-nat'
    LOG_FILE=/dev/null
    kvm_network_apply
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'DRY-RUN would execute'* ]]
  [[ "$output" == *'net-define'* ]]
  [[ "$output" == *'net-start'* ]]
}

@test "custom NAT apply is security blocked when dry-run is off" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/modules/virtualization/24_networks.sh'
    CURRENT_SCOPE=KVM
    DRY_RUN=false
    REAL_MACHINE_APPROVED=false
    REPO_ROOT='$REPO_ROOT'
    LOG_FILE=/dev/null
    kvm_network_apply
  "
  [ "$status" -eq 5 ]
  [[ "$output" == *'SECURITY_BLOCK'* ]]
}

@test "network module has no raw nftables or virsh mutation bypass" {
  run grep -E '^[[:space:]]*(sudo[[:space:]]+)?nft[[:space:]]+(add|create|delete|destroy|flush|insert|replace)[[:space:]]|^[[:space:]]*(sudo[[:space:]]+)?iptables[[:space:]]+-|^[[:space:]]*(sudo[[:space:]]+)?virsh([[:space:]].*)?(net-define|net-start|net-autostart|net-destroy|net-undefine)' "$REPO_ROOT/modules/virtualization/24_networks.sh"
  [ "$status" -ne 0 ]
}
