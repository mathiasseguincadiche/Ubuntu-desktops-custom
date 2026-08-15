#!/usr/bin/env bash
set -Eeuo pipefail

backup_preflight_precheck() {
  assert_scope BACKUP
  command -v findmnt >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
  command -v df >/dev/null 2>&1 || return "$EXIT_PRECHECK_FAILED"
}

backup_preflight_plan() {
  cat <<'EOF'
BACKUP PRECHECK / PLAN:
- require an external backup target; never use the protected system disk as the only copy
- discover target filesystem, mountpoint, free space and write capability read-only first
- require encrypted restic repository with credentials injected at runtime
- inventory HOST configuration and project manifests
- inventory libvirt network/domain/storage metadata
- inventory VM qcow2 disks and cloud-init metadata
- refuse unsafe live qcow2 file copies; require guest shutdown or supported quiesced/snapshot workflow
- calculate required capacity before backup
- preserve ownership, permissions and metadata where applicable
- fail closed when target, repository, credentials or VM consistency cannot be proven
EOF
}

backup_preflight_apply() {
  log_info BACKUP 'backup preflight APPLY intentionally disabled during architecture/pre-test phase'
}

backup_preflight_postcheck() {
  command -v findmnt >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}
