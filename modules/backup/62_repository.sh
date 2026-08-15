#!/usr/bin/env bash
set -Eeuo pipefail

backup_repository_precheck() { assert_scope BACKUP; }
backup_repository_plan() {
  cat <<'EOF'
RESTIC REPOSITORY CONTRACT:
- repository must be external to the protected system disk
- encryption is mandatory
- repository password/credentials must come from runtime secret input, never Git
- verify target free space and filesystem health before writing
- initialize only after explicit real-machine approval
- run repository integrity checks after backup according to validation policy
- never delete old snapshots before a new verified snapshot exists
EOF
}
backup_repository_apply() { log_info BACKUP 'restic repository APPLY disabled during architecture/pre-test phase'; }
backup_repository_postcheck() { return 0; }
