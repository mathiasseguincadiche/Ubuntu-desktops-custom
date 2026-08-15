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
  : > "$tmp/pool/base/ubuntu-26.04-server-cloudimg-amd64.img"
  : > "$tmp/pool/seeds/ubuntu-devops-seed.img"
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
