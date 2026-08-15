#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "VM provision apply is simulated in dry-run" {
  tmp="$(mktemp -d)"
  cat > "$tmp/ubuntu-devops-vm-identity.env" <<'EOF'
VM_DEVOPS_RESOLVED_MAC=52:54:00:12:34:56
VM_DEVOPS_RESOLVED_IP=192.168.50.150
VM_ADMIN_USER=devops
EOF
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh'
    CURRENT_SCOPE=VM_DEVOPS
    DRY_RUN=true
    REAL_MACHINE_APPROVED=false
    STATE_ROOT='$tmp'
    REPO_ROOT='$REPO_ROOT'
    KVM_POOL_PATH='/data/libvirt/images'
    LOG_FILE=/dev/null
    vm_provision_apply
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *'DRY-RUN would execute'* ]]
  [[ "$output" == *'virt-install'* ]]
  [[ "$output" == *'net-update'* ]]
}

@test "VM provision apply is blocked when real gate is closed" {
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/pool/base" "$tmp/pool/seeds"
  printf 'fixture\n' > "$tmp/pool/base/ubuntu-26.04-server-cloudimg-amd64.img"
  printf 'fixture\n' > "$tmp/pool/seeds/ubuntu-devops-seed.img"
  cat > "$tmp/ubuntu-devops-vm-identity.env" <<'EOF'
VM_DEVOPS_RESOLVED_MAC=52:54:00:12:34:56
VM_DEVOPS_RESOLVED_IP=192.168.50.150
VM_ADMIN_USER=devops
EOF
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh'
    CURRENT_SCOPE=VM_DEVOPS
    DRY_RUN=false
    REAL_MACHINE_APPROVED=false
    STATE_ROOT='$tmp'
    REPO_ROOT='$REPO_ROOT'
    KVM_POOL_PATH='$tmp/pool'
    LOG_FILE=/dev/null
    vm_provision_apply
  "
  rm -rf "$tmp"
  [ "$status" -eq 5 ]
  [[ "$output" == *'SECURITY_BLOCK'* ]]
}

@test "VM provisioning defines targeted rollback for partial resources" {
  grep -F 'vm_provision_rollback()' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
  grep -F 'net-update "$network" delete ip-dhcp-host' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
  grep -F 'undefine "$name" --nvram' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
  grep -F 'sudo rm -f -- "$disk"' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
}

@test "virt-install failure invokes rollback before returning apply failure" {
  grep -F 'vm_provision_rollback "$uri" "$network" "$name" "$disk" "$mac" "$ip" "$reservation_added"' \
    "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
  grep -F 'return "$EXIT_ROLLBACK_FAILED"' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
}
