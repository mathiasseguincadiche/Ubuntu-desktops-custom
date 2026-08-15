#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "backup verifier requires runtime repository and password file" {
  grep -F 'BACKUP_REPOSITORY_RUNTIME' "$REPO_ROOT/verify-preapply-backup.sh"
  grep -F 'RESTIC_PASSWORD_FILE' "$REPO_ROOT/verify-preapply-backup.sh"
}

@test "local backup target must be off the root filesystem" {
  grep -F 'findmnt -n -o SOURCE /' "$REPO_ROOT/verify-preapply-backup.sh"
  grep -F 'root_source" != "$repo_source' "$REPO_ROOT/verify-preapply-backup.sh"
}

@test "backup verifier requires an existing snapshot and full data check" {
  grep -F -- '--no-lock --json snapshots' "$REPO_ROOT/verify-preapply-backup.sh"
  grep -F -- '--no-lock check --read-data' "$REPO_ROOT/verify-preapply-backup.sh"
}

@test "backup proof records commit timestamp and verified verdict" {
  grep -F "printf 'commit=%s" "$REPO_ROOT/verify-preapply-backup.sh"
  grep -F "printf 'created_epoch=%s" "$REPO_ROOT/verify-preapply-backup.sh"
  grep -F "printf 'verdict=BACKUP_VERIFIED" "$REPO_ROOT/verify-preapply-backup.sh"
}

@test "no backup verification proof is committed to repository" {
  [ ! -e "$REPO_ROOT/state/real-apply/backup-verified.pass" ]
}
