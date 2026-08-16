#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "backup policy requires external encrypted verified target" {
  grep -F 'BACKUP_REQUIRE_EXTERNAL_TARGET=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_ENCRYPTION_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_INTEGRITY_CHECK_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_RESTORE_TEST_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
}

@test "pre-apply backup verifier accepts canonical and Restic repository env names" {
  script="$REPO_ROOT/verify-preapply-backup.sh"
  grep -F 'repo_runtime="${BACKUP_REPOSITORY_RUNTIME:-}"' "$script"
  grep -F 'repo_restic="${RESTIC_REPOSITORY:-}"' "$script"
  grep -F 'BACKUP_REPOSITORY_RUNTIME and RESTIC_REPOSITORY disagree.' "$script"
  grep -F 'BACKUP_REPOSITORY_RUNTIME or RESTIC_REPOSITORY is required.' "$script"
  grep -F 'restic --repo "$repo" --password-file "$password_file" --no-lock check --read-data' "$script"
}

@test "backup documentation uses the verifier runtime contract" {
  grep -F 'export BACKUP_REPOSITORY_RUNTIME=/chemin/externe/restic' "$REPO_ROOT/docs/BACKUP_RESTORE_RUNBOOK.md"
  grep -F 'RESTIC_REPOSITORY' "$REPO_ROOT/docs/BACKUP_RESTORE_RUNBOOK.md"
  grep -F 'export BACKUP_REPOSITORY_RUNTIME=/chemin/externe/restic' "$REPO_ROOT/docs/INSTALLATION_GUIDE.md"
}

@test "unsafe live qcow2 copy is forbidden" {
  grep -F 'BACKUP_ALLOW_LIVE_QCOW2_COPY=false' "$REPO_ROOT/config/backup.conf"
  grep -F 'raw copy of a live changing qcow2 file is forbidden' "$REPO_ROOT/modules/backup/65_vm_backup.sh"
}

@test "retention baseline is declared" {
  grep -F 'BACKUP_RETENTION_DAILY=7' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_RETENTION_WEEKLY=4' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_RETENTION_MONTHLY=6' "$REPO_ROOT/config/backup.conf"
}

@test "restore stages data before destructive promotion" {
  grep -F 'restore into a staging directory by default' "$REPO_ROOT/modules/backup/67_restore.sh"
  grep -F 'explicit approval for overwrite/destructive promotion' "$REPO_ROOT/modules/backup/67_restore.sh"
}

@test "disaster recovery restores network isolation before VM boot" {
  grep -F 'revalidate LAN isolation before any VM boot' "$REPO_ROOT/modules/backup/68_disaster_recovery.sh"
}

@test "backup chain ends in explicit readiness verdict" {
  grep -F 'BACKUP RESTORE CONTRACT READY' "$REPO_ROOT/modules/backup/70_backup_validation.sh"
}

@test "all backup apply functions remain non-mutating in architecture phase" {
  run grep -R -n -E '^[[:space:]]*(restic|virsh|qemu-img|cp|rsync|rm|mv|mount|umount)([[:space:]]|$)' "$REPO_ROOT/modules/backup"
  [ "$status" -ne 0 ]
}
