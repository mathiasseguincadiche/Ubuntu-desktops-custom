#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "VM DevOps chain is ordered from KVM validation to backup" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; printf '%s|%s|%s\n' \"\${CATALOG_DEPS[vm.preflight]}\" \"\${CATALOG_DEPS[vm.validation]}\" \"\${CATALOG_DEPS[backup.preflight]}\""
  [ "$status" -eq 0 ]
  [[ "$output" == "kvm.validation|vm.devsecops|host.validation kvm.validation vm.validation" ]]
}

@test "every VM DevOps contract exposes four adapter functions" {
  modules=(
    40_vm_preflight.sh 41_cloud_init.sh 42_identity_ssh.sh 43_base_tooling.sh
    44_git.sh 45_cloud_clis.sh 46_iac.sh 47_docker.sh 48_kubernetes.sh
    49_devsecops.sh 54_vm_validation.sh
  )
  for file in "${modules[@]}"; do
    run grep -E '^[a-z0-9_]+_(precheck|plan|apply|postcheck)\(\)' "$REPO_ROOT/modules/devops-vm/$file"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
  done
}

@test "VM DevOps architecture contains no active package or service mutation" {
  run bash -c "if grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(apt|apt-get|snap|systemctl|docker|kubectl|helm|kind)([[:space:]]|$)' --include='*.sh' '$REPO_ROOT/modules/devops-vm'; then exit 1; else exit 0; fi"
  [ "$status" -eq 0 ]
}

@test "cloud-init is key-only and keeps guest on DHCP" {
  run grep -F 'ssh_pwauth: false' "$REPO_ROOT/virtualization/cloud-init/user-data.tpl"
  [ "$status" -eq 0 ]
  run grep -F 'lock_passwd: true' "$REPO_ROOT/virtualization/cloud-init/user-data.tpl"
  [ "$status" -eq 0 ]
  run grep -F '__VM_ADMIN_SSH_PUBLIC_KEY__' "$REPO_ROOT/virtualization/cloud-init/user-data.tpl"
  [ "$status" -eq 0 ]
  run grep -F 'dhcp4: true' "$REPO_ROOT/virtualization/cloud-init/network-config.tpl"
  [ "$status" -eq 0 ]
}

@test "VM sizing matches frozen workstation allocation" {
  run grep -F 'VM_DEVOPS_RAM_MB=16384' "$REPO_ROOT/config/devops-vm.conf"
  [ "$status" -eq 0 ]
  run grep -F 'VM_DEVOPS_VCPU=8' "$REPO_ROOT/config/devops-vm.conf"
  [ "$status" -eq 0 ]
  run grep -F 'VM_DEVOPS_DISK_GB=200' "$REPO_ROOT/config/devops-vm.conf"
  [ "$status" -eq 0 ]
}

@test "DevOps manifest includes required tools and official version policy" {
  for token in git docker-engine kubectl helm kind terraform ansible aws-cli-v2 azure-cli trivy gitleaks; do
    run grep -F "$token" "$REPO_ROOT/manifests/devops-vm/tools.yml"
    [ "$status" -eq 0 ]
  done
  run grep -F 'strategy: resolve-latest-supported-stable-at-pretest' "$REPO_ROOT/manifests/devops-vm/tools.yml"
  [ "$status" -eq 0 ]
  run grep -F 'sources: official-upstream-only' "$REPO_ROOT/manifests/devops-vm/tools.yml"
  [ "$status" -eq 0 ]
}

@test "HOST remains forbidden from owning DevOps tooling" {
  run grep -F 'devops_tooling_on_host: forbidden' "$REPO_ROOT/manifests/devops-vm/tools.yml"
  [ "$status" -eq 0 ]
}

@test "VM validation uses architecture readiness verdict" {
  run grep -F 'VM DEVOPS CONTRACT READY' "$REPO_ROOT/modules/devops-vm/54_vm_validation.sh"
  [ "$status" -eq 0 ]
}
