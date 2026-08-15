#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "VM DevOps chain orders identity before cloud-init and provision" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; printf '%s\n' \"\${CATALOG_ORDER[@]}\""
  [ "$status" -eq 0 ]
  [[ "$output" == *$'vm.preflight\nvm.identity_ssh\nvm.cloud_init\nvm.provision\nvm.base'* ]]
}

@test "every VM DevOps contract exposes four adapter functions" {
  modules=(
    40_vm_preflight.sh 42_identity_ssh.sh 41_cloud_init.sh 42a_provision_vm.sh
    43_base_tooling.sh 44_git.sh 45_cloud_clis.sh 46_iac.sh 47_docker.sh
    48_kubernetes.sh 49_devsecops.sh 54_vm_validation.sh
  )
  for file in "${modules[@]}"; do
    run grep -E '^[a-z0-9_]+_(precheck|plan|apply|postcheck)\(\)' "$REPO_ROOT/modules/devops-vm/$file"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
  done
}

@test "VM image and provisioning mutations use secure runner" {
  grep -F 'run_mutating VM_DEVOPS' "$REPO_ROOT/modules/devops-vm/41_cloud_init.sh"
  grep -F 'run_mutating VM_DEVOPS' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
  run grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(apt|apt-get|qemu-img|virt-install)([[:space:]]|$)|^[[:space:]]*(sudo[[:space:]]+)?virsh([[:space:]].*)?(net-update|define|create)' "$REPO_ROOT/modules/devops-vm"
  [ "$status" -ne 0 ]
}

@test "Ubuntu cloud image fetch verifies GPG then SHA256" {
  grep -F "KEYRING='/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg'" "$REPO_ROOT/scripts/kvm/fetch_ubuntu_2604_cloud_image.sh"
  grep -F 'gpgv --keyring "$KEYRING"' "$REPO_ROOT/scripts/kvm/fetch_ubuntu_2604_cloud_image.sh"
  grep -F 'sha256sum -c image.sha256' "$REPO_ROOT/scripts/kvm/fetch_ubuntu_2604_cloud_image.sh"
}

@test "cloud-init is key-only and keeps guest on DHCP" {
  grep -F 'ssh_pwauth: false' "$REPO_ROOT/virtualization/cloud-init/user-data.tpl"
  grep -F 'lock_passwd: true' "$REPO_ROOT/virtualization/cloud-init/user-data.tpl"
  grep -F '__VM_ADMIN_SSH_PUBLIC_KEY__' "$REPO_ROOT/virtualization/cloud-init/user-data.tpl"
  grep -F 'dhcp4: true' "$REPO_ROOT/virtualization/cloud-init/network-config.tpl"
}

@test "VM identity is deterministic and constrained to DHCP pool" {
  grep -F "mac=\"52:54:00:" "$REPO_ROOT/modules/devops-vm/42_identity_ssh.sh"
  grep -F 'ip_octet=$((100 + (byte % 101)))' "$REPO_ROOT/modules/devops-vm/42_identity_ssh.sh"
  grep -F 'net-dhcp-leases' "$REPO_ROOT/modules/devops-vm/42_identity_ssh.sh"
}

@test "VM sizing matches frozen workstation allocation" {
  grep -F 'VM_DEVOPS_RAM_MB=16384' "$REPO_ROOT/config/devops-vm.conf"
  grep -F 'VM_DEVOPS_VCPU=8' "$REPO_ROOT/config/devops-vm.conf"
  grep -F 'VM_DEVOPS_DISK_GB=200' "$REPO_ROOT/config/devops-vm.conf"
}

@test "VM provisioning binds only to custom NAT" {
  grep -F 'network="${VM_DEVOPS_NETWORK:-devops-nat}"' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
  grep -F -- '--network "network=$network,model=virtio,mac=$mac"' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
  run grep -E -- '--network[[:space:]]+(bridge|direct)=' "$REPO_ROOT/modules/devops-vm/42a_provision_vm.sh"
  [ "$status" -ne 0 ]
}

@test "DevOps manifest includes required tools and official version policy" {
  for token in git docker-engine kubectl helm kind terraform ansible aws-cli-v2 azure-cli trivy gitleaks; do
    grep -F "$token" "$REPO_ROOT/manifests/devops-vm/tools.yml"
  done
  grep -F 'strategy: resolve-latest-supported-stable-at-pretest' "$REPO_ROOT/manifests/devops-vm/tools.yml"
  grep -F 'sources: official-upstream-only' "$REPO_ROOT/manifests/devops-vm/tools.yml"
}

@test "HOST remains forbidden from owning DevOps tooling" {
  grep -F 'devops_tooling_on_host: forbidden' "$REPO_ROOT/manifests/devops-vm/tools.yml"
}

@test "VM validation uses architecture readiness verdict" {
  grep -F 'VM DEVOPS CONTRACT READY' "$REPO_ROOT/modules/devops-vm/54_vm_validation.sh"
}
