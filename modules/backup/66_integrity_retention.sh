#!/usr/bin/env bash
set -Eeuo pipefail

backup_integrity_precheck() { assert_scope BACKUP; }
backup_integrity_plan() {
  cat <<'EOF'
INTEGRITY / RETENTION:
- verify new snapshot before pruning
- require restic repository check according to validation policy
- retention baseline: 7 daily, 4 weekly, 6 monthly snapshots
- pruning is a separate explicit destructive operation and must use the secure runner/gate
- maintain backup reports containing snapshot ID, timestamp, protected assets and verification result
- backup SUCCESS requires integrity verification; command exit code alone is insufficient
EOF
}
backup_integrity_apply() { log_info BACKUP 'integrity/retention APPLY disabled during architecture/pre-test phase'; }
backup_integrity_postcheck() { return 0; }
