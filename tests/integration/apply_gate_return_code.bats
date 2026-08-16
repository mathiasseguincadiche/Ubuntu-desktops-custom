#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "installer preserves the original REAL APPLY gate failure status" {
  installer="$REPO_ROOT/install.sh"

  run grep -F 'if ! apply_gate_open_runtime; then' "$installer"
  [ "$status" -ne 0 ]

  grep -Fq 'if apply_gate_open_runtime; then' "$installer"
  grep -Fq 'rc=$?' "$installer"
  grep -Fq 'exit "$rc"' "$installer"
}

@test "bash else branch captures command failure instead of negation status" {
  run bash -c '
    gate() { return 8; }
    if gate; then
      exit 99
    else
      rc=$?
    fi
    printf "%s\n" "$rc"
    exit "$rc"
  '
  [ "$status" -eq 8 ]
  [ "$output" = '8' ]
}
