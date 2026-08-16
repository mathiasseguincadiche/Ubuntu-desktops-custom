#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "backup policy requires external encrypted verified target" {
  grep -F 'BACKUP_REQUIRE_EXTERNAL_TARGET=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_ENCRYPTION_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_INTEGRITY_CHECK_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_RESTORE_TEST_REQUIRED=true' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_PREAPPLY_REPOSITORY_SUBDIR=Backup-Ubuntu/restic' "$REPO_ROOT/config/backup.conf"
  grep -F 'BACKUP_PREAPPLY_REQUIRED_FSTYPE=ext4' "$REPO_ROOT/config/backup.conf"
}

@test "pre-apply backup verifier accepts canonical and Restic repository env names" {
  script="$REPO_ROOT/verify-preapply-backup.sh"
  grep -F 'repo_runtime="${BACKUP_REPOSITORY_RUNTIME:-}"' "$script"
  grep -F 'repo_restic="${RESTIC_REPOSITORY:-}"' "$script"
  grep -F 'BACKUP_REPOSITORY_RUNTIME and RESTIC_REPOSITORY disagree.' "$script"
  grep -F 'BACKUP_REPOSITORY_RUNTIME or RESTIC_REPOSITORY is required.' "$script"
  grep -F 'restic --repo "$repo" --password-file "$password_file" --no-lock check --read-data' "$script"
}

@test "local pre-apply backup target must be proven external" {
  script="$REPO_ROOT/verify-preapply-backup.sh"
  grep -F 'backup_local_source_is_external()' "$script"
  grep -F 'lsblk -s -n -p -o NAME,TYPE,TRAN,RM,HOTPLUG' "$script"
  grep -F '[[ "$tran" == usb || "$removable" == 1 || "$hotplug" == 1 ]]' "$script"
  grep -F 'a second internal SSD is insufficient.' "$script"
  grep -F 'BACKUP_REQUIRE_EXTERNAL_TARGET' "$script"
}

@test "pre-apply backup preparation is automated and remains fail-closed" {
  script="$REPO_ROOT/prepare-preapply-backup.sh"
  grep -F 'apply_gate_verify_dryrun_proof' "$script"
  grep -F 'BACKUP_TARGET_MOUNT_RUNTIME' "$script"
  grep -F 'BACKUP_PREAPPLY_REPOSITORY_SUBDIR' "$script"
  grep -F 'backup_local_source_is_external()' "$script"
  grep -F 'restic --repo "$repository" --password-file "$password_file" init' "$script"
  grep -F 'restic --repo "$repository" --password-file "$password_file" backup' "$script"
  grep -F 'restic --repo "$repository" --password-file "$password_file" restore "$snapshot_id"' "$script"
  grep -F '"$REPO_ROOT/verify-preapply-backup.sh"' "$script"
  grep -F 'apply_gate_verify_backup_proof' "$script"
  run grep -E '(^|[[:space:]])(mkfs|parted|wipefs|fdisk|sgdisk)([[:space:]]|$)' "$script"
  [ "$status" -ne 0 ]
}

@test "pre-apply free-space probe uses compatible GNU df options" {
  script="$REPO_ROOT/prepare-preapply-backup.sh"
  grep -F 'df -B1 --output=avail "$mountpoint"' "$script"
  run grep -F 'df -PB1 --output=avail' "$script"
  [ "$status" -ne 0 ]
}

@test "interactive menu places verified backup before real apply" {
  menu="$REPO_ROOT/menu.sh"
  grep -F '3) Préparer et vérifier le backup pré-APPLY (Restic)' "$menu"
  grep -F '4) Installation reelle protegee (--apply)' "$menu"
  grep -F '3) bash "$REPO_ROOT/prepare-preapply-backup.sh" ;;' "$menu"
}

@test "backup documentation uses the verifier runtime contract" {
  grep -F 'export BACKUP_REPOSITORY_RUNTIME=/chemin/externe/restic' "$REPO_ROOT/docs/BACKUP_RESTORE_RUNBOOK.md"
  grep -F 'RESTIC_REPOSITORY' "$REPO_ROOT/docs/BACKUP_RESTORE_RUNBOOK.md"
  grep -F 'export BACKUP_REPOSITORY_RUNTIME=/chemin/externe/restic' "$REPO_ROOT/docs/INSTALLATION_GUIDE.md"
  grep -Fi 'un second SSD interne ne satisfait pas' "$REPO_ROOT/docs/BACKUP_RESTORE_RUNBOOK.md"
  grep -F './prepare-preapply-backup.sh' "$REPO_ROOT/docs/BACKUP_RESTORE_RUNBOOK.md"
  grep -F '3) Préparer et vérifier le backup pré-APPLY' "$REPO_ROOT/docs/INSTALLATION_GUIDE.md"
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
