#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "KVM chain is ordered from preflight to validation" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; module_catalog_validate; printf '%s\n' \"\${CATALOG_ORDER[@]}\""
  [ "$status" -eq 0 ]
  [[ "$output" == *$'kvm.preflight\nkvm.stack\nkvm.firmware\nkvm.storage\nkvm.network\nkvm.catalog\nkvm.cli\nkvm.ssh\nkvm.validation'* ]]
}

@test "every KVM contract exposes four adapter functions" {
  run bash -c "source '$REPO_ROOT/lib/constants.sh'; source '$REPO_ROOT/lib/scope.sh'; source '$REPO_ROOT/lib/module_catalog.sh'; REPO_ROOT='$REPO_ROOT'; module_catalog_load '$REPO_ROOT/manifests/module-plan.conf'; for id in \"\${CATALOG_ORDER[@]}\"; do [[ \"\${CATALOG_SCOPE[\$id]}\" == KVM ]] || continue; source \"$REPO_ROOT/\${CATALOG_PATH[\$id]}\"; prefix=\"\${id//./_}\"; declare -F \"\${prefix}_precheck\" >/dev/null; declare -F \"\${prefix}_plan\" >/dev/null; declare -F \"\${prefix}_apply\" >/dev/null; declare -F \"\${prefix}_postcheck\" >/dev/null; done"
  [ "$status" -eq 0 ]
}

@test "implemented KVM mutations use secure runner" {
  local file
  for file in 21_stack_qemu_libvirt.sh 22_firmware_uefi_tpm.sh 23_storage_pools.sh 24_networks.sh 25_os_catalog.sh; do
    grep -F 'run_mutating KVM' "$REPO_ROOT/modules/virtualization/$file"
  done
}

@test "KVM modules contain no raw package or libvirt mutation bypass" {
  run grep -R -n -E '^[[:space:]]*(sudo[[:space:]]+)?(apt|apt-get)[[:space:]]+(install|upgrade)|^[[:space:]]*(sudo[[:space:]]+)?virsh([[:space:]].*)?(net-define|net-start|pool-define|pool-start|define|create)' "$REPO_ROOT/modules/virtualization"
  [ "$status" -ne 0 ]
}

@test "custom network implementation preserves project ownership boundaries" {
  grep -F 'KVM_FIREWALL_ENFORCEMENT=project-nftables-guard' "$REPO_ROOT/config/virtualization.conf"
  grep -F 'KVM_DNS_ENFORCEMENT=libvirt-dns-forwarders' "$REPO_ROOT/config/virtualization.conf"
  grep -F "TABLE_NAME='ubuntu_desktops_custom_kvm'" "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh"
}

@test "KVM stack keeps CLI primary with virt-manager as fallback and dynamic Intel render detection" {
  grep -F 'virt-install virt-manager virt-viewer' "$REPO_ROOT/modules/virtualization/21_stack_qemu_libvirt.sh"
  grep -F 'osinfo-db' "$REPO_ROOT/modules/virtualization/21_stack_qemu_libvirt.sh"
  grep -F "0x8086" "$REPO_ROOT/modules/virtualization/21_stack_qemu_libvirt.sh"
  run grep -F '/dev/dri/renderD128' "$REPO_ROOT/modules/virtualization/21_stack_qemu_libvirt.sh"
  [ "$status" -ne 0 ]
}

@test "OS catalog pins official Ubuntu 26.04 artifacts and has a real verified refresh path" {
  run grep -E 'ubuntu-26\.04-(desktop-amd64\.iso|live-server-amd64\.iso|server-cloudimg-amd64\.img)' "$REPO_ROOT/manifests/virtualization/os-catalog.yml"
  [ "$status" -eq 0 ]
  grep -F 'refresh_os_catalog.sh' "$REPO_ROOT/modules/virtualization/25_os_catalog.sh"
  grep -F 'status=verified' "$REPO_ROOT/modules/virtualization/25_os_catalog.sh"
  grep -F 'SHA256SUMS' "$REPO_ROOT/manifests/virtualization/os-catalog.yml"
  grep -F 'curl -fsSL' "$REPO_ROOT/scripts/kvm/refresh_os_catalog.sh"
}

@test "optional desktop profiles remain outside automatic workstation provisioning" {
  grep -F 'UBUNTU_DESKTOP_VCPU=6' "$REPO_ROOT/config/vm-profiles.conf"
  grep -F 'UBUNTU_DESKTOP_RAM_MB=8192' "$REPO_ROOT/config/vm-profiles.conf"
  grep -F 'WINDOWS11_VCPU=8' "$REPO_ROOT/config/vm-profiles.conf"
  grep -F 'WINDOWS11_RAM_MB=16384' "$REPO_ROOT/config/vm-profiles.conf"
  run grep -E 'ubuntu-desktop|windows-11' "$REPO_ROOT/manifests/module-plan.conf"
  [ "$status" -ne 0 ]
}

@test "GPU passthrough is explicitly prohibited by the architecture" {
  grep -F 'VM_PROFILE_GPU_PASSTHROUGH_ALLOWED=false' "$REPO_ROOT/config/vm-profiles.conf"
  grep -F 'Aucun GPU passthrough/VFIO' "$REPO_ROOT/docs/RUNBOOK_OPERATIONS.md"
  run grep -E -- '--host-device|<hostdev' "$REPO_ROOT/scripts/kvm/vm-profile"
  [ "$status" -ne 0 ]
}

@test "Ubuntu Desktop profile uses dynamic Intel render node and accelerated VirtIO GPU" {
  grep -F 'UBUNTU_DESKTOP_RENDER_NODE=auto-intel' "$REPO_ROOT/config/vm-profiles.conf"
  grep -F "vendor,,}" "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F "0x8086" "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F 'gl.rendernode=' "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F -- '--video virtio,accel3d=yes' "$REPO_ROOT/scripts/kvm/vm-profile"
}

@test "Windows 11 profile requires Secure Boot TPM 2.0 and VirtIO media" {
  grep -F 'WINDOWS11_FIRMWARE=uefi-secureboot' "$REPO_ROOT/config/vm-profiles.conf"
  grep -F 'firmware.feature0.name=secure-boot' "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F 'firmware.feature1.name=enrolled-keys' "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F 'backend.version=2.0,model=tpm-crb' "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F -- '--virtio-iso is required for windows-11' "$REPO_ROOT/scripts/kvm/vm-profile"
}

@test "on-demand VM creation is interactive and rollback scoped" {
  grep -F 'Interactive TTY required for VM creation.' "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F 'CREATE_$VM_NAME' "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F 'rollback_created_vm' "$REPO_ROOT/scripts/kvm/vm-profile"
  grep -F 'vol-delete --pool "$VM_PROFILE_DEFAULT_POOL" "$VM_NAME.qcow2"' "$REPO_ROOT/scripts/kvm/vm-profile"
}

@test "KVM validation advertises architecture readiness" {
  run grep -F 'KVM CONTRACT READY' "$REPO_ROOT/modules/virtualization/30_virtualization_validation.sh"
  [ "$status" -eq 0 ]
}
