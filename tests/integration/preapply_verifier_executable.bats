#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"; }

@test "pre-apply verifier remains executable because the preparer invokes it directly" {
  [ -x "$REPO_ROOT/verify-preapply-backup.sh" ]
  grep -F '"$REPO_ROOT/verify-preapply-backup.sh"' "$REPO_ROOT/prepare-preapply-backup.sh"
}
