#!/usr/bin/env bash

bootstrap_repo_root() {
  local source_dir
  source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$source_dir/.." && pwd
}

engine_bootstrap() {
  REPO_ROOT="${REPO_ROOT:-$(bootstrap_repo_root)}"

  # shellcheck source=lib/constants.sh
  source "$REPO_ROOT/lib/constants.sh"
  # shellcheck source=lib/common.sh
  source "$REPO_ROOT/lib/common.sh"
  # shellcheck source=lib/config.sh
  source "$REPO_ROOT/lib/config.sh"
  # shellcheck source=lib/logging.sh
  source "$REPO_ROOT/lib/logging.sh"
  # shellcheck source=lib/state.sh
  source "$REPO_ROOT/lib/state.sh"
  # shellcheck source=lib/scope.sh
  source "$REPO_ROOT/lib/scope.sh"
  # shellcheck source=lib/locks.sh
  source "$REPO_ROOT/lib/locks.sh"
  # shellcheck source=lib/retry.sh
  source "$REPO_ROOT/lib/retry.sh"
  # shellcheck source=lib/runner.sh
  source "$REPO_ROOT/lib/runner.sh"

  DRY_RUN="${DRY_RUN:-true}"
  config_load_dir "$REPO_ROOT/config"

  LOG_ROOT="${LOG_ROOT:-$REPO_ROOT/logs}"
  STATE_ROOT="${STATE_ROOT:-$REPO_ROOT/state}"
  REPORT_ROOT="${REPORT_ROOT:-$REPO_ROOT/reports}"
  RUN_ID="${RUN_ID:-$(uw_run_id)}"

  safe_mkdir "$LOG_ROOT"
  safe_mkdir "$STATE_ROOT"
  safe_mkdir "$REPORT_ROOT"
  log_init
  state_init

  log_info ENGINE "bootstrap run_id=$RUN_ID dry_run=$DRY_RUN real_machine_approved=${REAL_MACHINE_APPROVED:-false}"
}
