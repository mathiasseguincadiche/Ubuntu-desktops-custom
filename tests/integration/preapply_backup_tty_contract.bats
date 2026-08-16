#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "Restic passphrase prompt requires interactive stdin but not captured stdout" {
  script="$REPO_ROOT/prepare-preapply-backup.sh"

  grep -F 'password_file="$(backup_password_file)"' "$script"
  grep -F "[[ -t 0 ]] || backup_fail 'interactive TTY required to create the Restic password file'" "$script"

  run grep -F '[[ -t 0 && -t 1 ]]' "$script"
  [ "$status" -ne 0 ]
}
