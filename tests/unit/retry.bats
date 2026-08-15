#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "$REPO_ROOT/lib/constants.sh"
  source "$REPO_ROOT/lib/retry.sh"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() { rm -rf "$TMPDIR_TEST"; }

@test "retry succeeds on a later attempt" {
  counter="$TMPDIR_TEST/counter"
  printf '0\n' > "$counter"
  attempt() {
    local n
    n="$(cat "$counter")"
    n=$((n + 1))
    printf '%s\n' "$n" > "$counter"
    (( n >= 3 ))
  }
  retry 3 0 attempt
  [ "$(cat "$counter")" = '3' ]
}
