#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

@test "desktop application mutations have human operator labels" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/ui.sh'
    source '$REPO_ROOT/lib/live_progress.sh'
    UI_STEP_ID=host.apps
    ui_live_action_label HOST 'sudo bash /repo/scripts/vendor/remove_retired_desktop_apps.sh'
    ui_live_action_label HOST 'sudo apt-get -y install libreoffice remmina filezilla'
    ui_live_action_label HOST 'sudo bash /repo/scripts/vendor/install_mozilla_repo.sh'
    ui_live_action_label HOST 'sudo bash /repo/scripts/vendor/install_proton_mail.sh'
    ui_live_action_label HOST 'sudo bash /repo/scripts/vendor/install_vscode_repo.sh'
    ui_live_action_label HOST 'code --install-extension ms-vscode-remote.remote-ssh --force'
    ui_live_action_label HOST 'sudo bash /repo/scripts/vendor/install_brave_repo.sh'
    ui_live_action_label HOST 'sudo bash /repo/scripts/vendor/install_onlyoffice_repo.sh'
    ui_live_action_label HOST 'sudo bash /repo/scripts/vendor/install_flatpak_apps.sh'
    ui_live_action_label HOST 'sudo bash /repo/scripts/vendor/install_drawio_release.sh'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'Nettoyage des applications retirées'* ]]
  [[ "$output" == *'Paquets Ubuntu — FileZilla, Remmina, LibreOffice…'* ]]
  [[ "$output" == *'Firefox — dépôt officiel Mozilla'* ]]
  [[ "$output" == *'Proton Mail Desktop'* ]]
  [[ "$output" == *'Visual Studio Code — dépôt Microsoft'* ]]
  [[ "$output" == *'VS Code — extension Remote SSH'* ]]
  [[ "$output" == *'Brave Browser'* ]]
  [[ "$output" == *'ONLYOFFICE Desktop Editors'* ]]
  [[ "$output" == *'Bitwarden, OBS Studio et Extension Manager'* ]]
  [[ "$output" == *'draw.io Desktop'* ]]
}

@test "runner emits live begin and OK only for a real approved mutation" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/scope.sh'
    log_command() { :; }
    log_info() { :; }
    log_error() { :; }
    ui_live_progress_enabled() { return 0; }
    ui_live_action_label() { printf '%s\n' 'Action lisible'; }
    ui_live_action_begin() { printf 'BEGIN:%s\n' \"\$1\"; }
    ui_live_action_ok() { printf '%s\n' 'END:OK'; }
    ui_live_action_fail() { printf '%s\n' 'END:FAIL'; }
    source '$REPO_ROOT/lib/runner.sh'
    ACTIVE_SCOPE=HOST
    DRY_RUN=false
    REAL_MACHINE_APPROVED=true
    run_mutating HOST true
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'BEGIN:Action lisible'* ]]
  [[ "$output" == *'END:OK'* ]]
}

@test "runner emits live failure and preserves the command return code" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/scope.sh'
    log_command() { :; }
    log_info() { :; }
    log_error() { :; }
    ui_live_progress_enabled() { return 0; }
    ui_live_action_label() { printf '%s\n' 'Action en erreur'; }
    ui_live_action_begin() { printf 'BEGIN:%s\n' \"\$1\"; }
    ui_live_action_ok() { printf '%s\n' 'END:OK'; }
    ui_live_action_fail() { printf '%s\n' 'END:FAIL'; }
    source '$REPO_ROOT/lib/runner.sh'
    ACTIVE_SCOPE=HOST
    DRY_RUN=false
    REAL_MACHINE_APPROVED=true
    run_mutating HOST bash -c 'exit 7'
  "
  [ "$status" -eq 7 ]
  [[ "$output" == *'BEGIN:Action en erreur'* ]]
  [[ "$output" == *'END:FAIL'* ]]
}

@test "dry-run never activates live mutation progress" {
  run bash -c "
    source '$REPO_ROOT/lib/constants.sh'
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/lib/scope.sh'
    log_command() { :; }
    log_info() { printf '%s\n' \"\$2\"; }
    log_error() { :; }
    ui_live_progress_enabled() { printf '%s\n' 'LIVE_SHOULD_NOT_RUN'; return 0; }
    ui_live_action_label() { printf '%s\n' 'Action'; }
    ui_live_action_begin() { printf '%s\n' 'BEGIN'; }
    source '$REPO_ROOT/lib/runner.sh'
    ACTIVE_SCOPE=HOST
    DRY_RUN=true
    REAL_MACHINE_APPROVED=false
    run_mutating HOST touch /tmp/uw-live-progress-must-not-exist
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'DRY-RUN would execute'* ]]
  [[ "$output" != *'LIVE_SHOULD_NOT_RUN'* ]]
  [[ "$output" != *'BEGIN'* ]]
}

@test "bootstrap loads live progress before runner" {
  run grep -n -E 'source .*lib/(live_progress|runner)\.sh' "$REPO_ROOT/lib/bootstrap.sh"
  [ "$status" -eq 0 ]
  live_line="$(printf '%s\n' "$output" | grep 'live_progress.sh' | cut -d: -f1)"
  runner_line="$(printf '%s\n' "$output" | grep 'runner.sh' | cut -d: -f1)"
  [ "$live_line" -lt "$runner_line" ]
}
