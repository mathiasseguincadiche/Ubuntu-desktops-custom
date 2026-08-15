#!/usr/bin/env bash
set -Eeuo pipefail

kvm_storage_precheck() { assert_scope KVM; return 0; }
kvm_storage_plan() {
  cat <<'EOF'
PLAN: libvirt storage pools on DATA EXT4, qcow2 volumes, sparse allocation, ownership/permissions, capacity checks, snapshots and backup-compatible layouts.
EOF
}
kvm_storage_apply() { log_info KVM 'storage pool APPLY disabled during architecture pre-test'; }
kvm_storage_postcheck() { return 0; }
