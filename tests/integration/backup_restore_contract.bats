#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "backup policy requires external encrypted verified target" {
  grep -F 'BACKUP_REQUIRE_EXTERNAL_TARGET=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_ENCRYPTION_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_INTEGRITY_CHECK_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_RESTORE_TEST_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
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
