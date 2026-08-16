#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "KVM catalog precheck defers missing curl only during dry-run" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    assert_scope() { :; }
    log_info() { :; }
    command() {
      if [[ \"\$1\" == '-v' && \"\${2:-}\" == 'curl' ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    REPO_ROOT='$REPO_ROOT'
    DRY_RUN=true
    source '$REPO_ROOT/modules/virtualization/25_os_catalog.sh'
    kvm_catalog_precheck
  "
  [ "$status" -eq 0 ]

  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    assert_scope() { :; }
    log_info() { :; }
    command() {
      if [[ \"\$1\" == '-v' && \"\${2:-}\" == 'curl' ]]; then
        return 1
      fi
      builtin command \"\$@\"
    }
    REPO_ROOT='$REPO_ROOT'
    DRY_RUN=false
    source '$REPO_ROOT/modules/virtualization/25_os_catalog.sh'
    kvm_catalog_precheck
  "
  [ "$status" -eq 3 ]
}

@test "dry-run failure reporting captures orchestrator status inside else branch" {
  run grep -A12 -F 'if orchestrator_run_all; then' "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'else\n    rc=$?'* ]]
  [[ "$output" == *"VERDICT: FULL DRY-RUN FAIL (rc=%d)"* ]]

  run grep -E '^  rc=\$\?$' "$REPO_ROOT/install.sh"
  [ "$status" -ne 0 ]
}
