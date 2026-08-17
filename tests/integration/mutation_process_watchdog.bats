#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "watchdog configuration enables one bounded automatic recovery" {
  run bash -c "
    grep -F 'MUTATION_WATCHDOG_ENABLED=true' '$REPO_ROOT/config/security.conf'
    grep -F 'MUTATION_WATCHDOG_STOP_GRACE_SECONDS=5' '$REPO_ROOT/config/security.conf'
    grep -F 'MUTATION_WATCHDOG_AUTO_CONTINUE=true' '$REPO_ROOT/config/security.conf'
    grep -F 'MUTATION_WATCHDOG_MAX_AUTO_CONTINUES=1' '$REPO_ROOT/config/security.conf'
  "
  [ "$status" -eq 0 ]
}

@test "watchdog recognizes Linux job-control T state and exposes manual fallback" {
  run bash -c "
    grep -F '[[ \"\$stat\" == T* ]]' '$REPO_ROOT/lib/process_watchdog.sh'
    grep -F 'event=\$event' '$REPO_ROOT/lib/process_watchdog.sh'
    grep -F 'MANUAL_ACTION' '$REPO_ROOT/lib/process_watchdog.sh'
    grep -F 'sudo -n kill -CONT' '$REPO_ROOT/lib/process_watchdog.sh'
  "
  [ "$status" -eq 0 ]
}

@test "runner keeps mutation foreground and starts sidecar watchdog" {
  run bash -c "
    grep -F 'process_watchdog_start \"\${BASHPID:-\$\$}\"' '$REPO_ROOT/lib/runner.sh'
    grep -F 'if \"\$@\"; then' '$REPO_ROOT/lib/runner.sh'
    grep -F 'process_watchdog_stop \"\$watchdog_pid\"' '$REPO_ROOT/lib/runner.sh'
  "
  [ "$status" -eq 0 ]
}

@test "watchdog status is persisted in the current run state" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/live_progress.sh'
    source '$REPO_ROOT/lib/process_watchdog_ui.sh'
    source '$REPO_ROOT/lib/logging.sh'
    source '$REPO_ROOT/lib/process_watchdog.sh'

    LOG_ROOT='$TMPDIR_TEST/logs'
    RUN_ID=watchdog-status
    RUN_STATE_DIR='$TMPDIR_TEST/state/runs/watchdog-status'
    safe_mkdir \"\$LOG_ROOT\"
    safe_mkdir \"\$RUN_STATE_DIR\"
    log_init
    UI_MODE_CURRENT=technical

    process_watchdog_report SUSPENDED HOST 'Proton Mail Desktop' 156160 T+ 9 'apt-get -y install proton-mail.deb' 'test fixture'
    grep -F 'state=SUSPENDED' \"\$RUN_STATE_DIR/process-watchdog.status\"
    grep -F 'pid=156160' \"\$RUN_STATE_DIR/process-watchdog.status\"
    grep -F 'stat=T+' \"\$RUN_STATE_DIR/process-watchdog.status\"
    grep -F 'event=SUSPENDED' \"\$LOG_DIR/process-watchdog.log\"
  "
  [ "$status" -eq 0 ]
}
