#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "IaC tooling apply is fully simulated without VM credentials" {
  tmp="$(mktemp -d)"
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/lib/vm_remote.sh'
    source '$REPO_ROOT/modules/devops-vm/46_iac.sh'
    CURRENT_SCOPE=VM_DEVOPS
    DRY_RUN=true
    REAL_MACHINE_APPROVED=false
    STATE_ROOT='$tmp'
    REPO_ROOT='$REPO_ROOT'
    LOG_FILE=/dev/null
    vm_iac_apply
  "
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *'DRY-RUN would execute'* ]]
  [[ "$output" == *'scp'* ]]
  [[ "$output" == *'ssh'* ]]
}

@test "IaC tooling apply is blocked before transport when real gate is closed" {
  tmp="$(mktemp -d)"
  cat > "$tmp/ubuntu-devops-vm-identity.env" <<'EOF'
VM_DEVOPS_RESOLVED_IP=192.168.50.150
VM_ADMIN_USER=devops
EOF
  printf '%s\n' dummy > "$tmp/id_ed25519"
  chmod 600 "$tmp/id_ed25519"
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/scope.sh'
    source '$REPO_ROOT/lib/runner.sh'
    source '$REPO_ROOT/lib/vm_remote.sh'
    source '$REPO_ROOT/modules/devops-vm/46_iac.sh'
    CURRENT_SCOPE=VM_DEVOPS
    DRY_RUN=false
    REAL_MACHINE_APPROVED=false
    STATE_ROOT='$tmp'
    REPO_ROOT='$REPO_ROOT'
    VM_ADMIN_SSH_PRIVATE_KEY_FILE='$tmp/id_ed25519'
    LOG_FILE=/dev/null
    vm_iac_apply
  "
  rm -rf "$tmp"
  [ "$status" -eq 6 ]
  [[ "$output" == *'SECURITY_BLOCK'* ]]
}
