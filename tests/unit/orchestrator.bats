#!/usr/bin/env bats

setup() {
  export TMPROOT
  TMPROOT="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPROOT"
}

@test 'orchestrator executes PRECHECK PLAN APPLY POSTCHECK in order' {
  run env TMPROOT="$TMPROOT" bash -c '
    source lib/constants.sh
    source lib/common.sh
    source lib/logging.sh
    source lib/state.sh
    source lib/scope.sh
    source lib/orchestrator.sh
    LOG_ROOT="$TMPROOT/logs"; STATE_ROOT="$TMPROOT/state"; REPORT_ROOT="$TMPROOT/reports"; RUN_ID=test
    safe_mkdir "$LOG_ROOT"; safe_mkdir "$STATE_ROOT"; safe_mkdir "$REPORT_ROOT"; log_init; state_init; orchestrator_reset
    pre(){ echo PRE >> "$TMPROOT/order"; }
    plan(){ echo PLAN >> "$TMPROOT/order"; }
    apply(){ echo APPLY >> "$TMPROOT/order"; }
    post(){ echo POST >> "$TMPROOT/order"; }
    orchestrator_register m1 HOST "" pre plan apply post
    orchestrator_run_all
    cat "$TMPROOT/order"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'PRE\nPLAN\nAPPLY\nPOST' ]
}

@test 'orchestrator blocks module when dependency is not successful' {
  run env TMPROOT="$TMPROOT" bash -c '
    source lib/constants.sh
    source lib/common.sh
    source lib/logging.sh
    source lib/state.sh
    source lib/scope.sh
    source lib/orchestrator.sh
    LOG_ROOT="$TMPROOT/logs"; STATE_ROOT="$TMPROOT/state"; REPORT_ROOT="$TMPROOT/reports"; RUN_ID=test
    safe_mkdir "$LOG_ROOT"; safe_mkdir "$STATE_ROOT"; safe_mkdir "$REPORT_ROOT"; log_init; state_init; orchestrator_reset
    orchestrator_register base HOST
    orchestrator_register child KVM base
    orchestrator_run_module child
  '
  [ "$status" -eq 4 ]
}

@test 'orchestrator resume skips already successful module' {
  run env TMPROOT="$TMPROOT" bash -c '
    source lib/constants.sh
    source lib/common.sh
    source lib/logging.sh
    source lib/state.sh
    source lib/scope.sh
    source lib/orchestrator.sh
    LOG_ROOT="$TMPROOT/logs"; STATE_ROOT="$TMPROOT/state"; REPORT_ROOT="$TMPROOT/reports"; RUN_ID=test; ORCH_RESUME=true
    safe_mkdir "$LOG_ROOT"; safe_mkdir "$STATE_ROOT"; safe_mkdir "$REPORT_ROOT"; log_init; state_init; orchestrator_reset
    apply(){ echo SHOULD_NOT_RUN >> "$TMPROOT/order"; }
    orchestrator_register m1 HOST "" "" "" apply ""
    state_set m1 SUCCESS done
    orchestrator_run_module m1
    test ! -e "$TMPROOT/order"
  '
  [ "$status" -eq 0 ]
}
