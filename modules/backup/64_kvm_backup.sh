#!/usr/bin/env bash
set -Eeuo pipefail

backup_kvm_precheck() { assert_scope BACKUP; }
backup_kvm_plan() {
  cat <<'EOF'
KVM/LIBVIRT BACKUP:
- export domain XML for managed VMs
- export devops-nat network definition and deterministic DHCP reservation metadata
- record storage pool definitions and volume mapping
- record UEFI/NVRAM and TPM state requirements when used by a VM
- do not treat libvirt metadata alone as a VM disk backup
- restoration must validate qemu:///system, pools, network isolation and VM definitions before guests start
EOF
}
backup_kvm_apply() { log_info BACKUP 'KVM metadata backup APPLY disabled during architecture/pre-test phase'; }
backup_kvm_postcheck() { return 0; }
