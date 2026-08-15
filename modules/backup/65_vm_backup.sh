#!/usr/bin/env bash
set -Eeuo pipefail

backup_vm_precheck() { assert_scope BACKUP; }
backup_vm_plan() {
  cat <<'EOF'
VM BACKUP CONSISTENCY CONTRACT:
- qcow2 VM disks are protected data
- raw copy of a live changing qcow2 file is forbidden
- preferred baseline: clean guest shutdown for full backup
- future online workflow may use supported libvirt/QEMU guest-agent quiesce and external snapshot/block-copy only after dedicated pre-test
- capture domain XML, cloud-init identity metadata, DHCP reservation and disk checksums with the backup set
- verify restored qcow2 with qemu-img check before first boot
EOF
}
backup_vm_apply() { log_info BACKUP 'VM backup APPLY disabled during architecture/pre-test phase'; }
backup_vm_postcheck() { return 0; }
