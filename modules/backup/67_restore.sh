#!/usr/bin/env bash
set -Eeuo pipefail

backup_restore_precheck() { assert_scope BACKUP; }
backup_restore_plan() {
  cat <<'EOF'
GRANULAR RESTORE CONTRACT:
- list snapshots and protected assets before selecting a restore point
- restore into a staging directory by default, never overwrite live data blindly
- support project/config restore independently from VM restore
- support libvirt metadata restore independently from qcow2 restore
- verify checksums/metadata before promotion into production paths
- require explicit approval for overwrite/destructive promotion
- preserve current data until restored data passes validation
EOF
}
backup_restore_apply() { log_info BACKUP 'restore APPLY disabled during architecture/pre-test phase'; }
backup_restore_postcheck() { return 0; }
