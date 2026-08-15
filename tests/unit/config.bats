#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "$REPO_ROOT/lib/constants.sh"
  source "$REPO_ROOT/lib/config.sh"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() { rm -rf "$TMPDIR_TEST"; }

@test "config loader parses simple values without executing shell" {
  marker="$TMPDIR_TEST/should-not-exist"
  cat > "$TMPDIR_TEST/test.conf" <<EOF
SAFE_VALUE=hello
LITERAL_COMMAND=\$(touch $marker)
EOF
  config_load_file "$TMPDIR_TEST/test.conf"
  [ "$SAFE_VALUE" = 'hello' ]
  [ "$LITERAL_COMMAND" = "\$(touch $marker)" ]
  [ ! -e "$marker" ]
}

@test "config loader rejects malformed lines" {
  printf '%s\n' 'not valid' > "$TMPDIR_TEST/bad.conf"
  run config_load_file "$TMPDIR_TEST/bad.conf"
  [ "$status" -eq "$EXIT_INVALID_ARGUMENT" ]
}
