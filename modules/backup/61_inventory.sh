#!/usr/bin/env bash
set -Eeuo pipefail

backup_inventory_precheck() { assert_scope BACKUP; }
backup_inventory_plan() {
  cat <<'EOF'
PROTECTED ASSET INVENTORY:
- project config/, manifests/, virtualization templates and documentation needed to rebuild
- selected HOST configuration required to reproduce workstation behavior
- libvirt domain XML, network XML, pool definitions and deterministic VM identity metadata
- VM qcow2 disks plus cloud-init metadata required for recovery
- package/application inventories are metadata, not substitutes for user data backups
- exclude transient caches, downloaded ISO artifacts that can be verified/re-fetched, and secrets not explicitly supplied by the operator
- produce a machine-readable inventory with size and source path before backup
EOF
}
backup_inventory_apply() { log_info BACKUP 'inventory APPLY disabled during architecture/pre-test phase'; }
backup_inventory_postcheck() { return 0; }
