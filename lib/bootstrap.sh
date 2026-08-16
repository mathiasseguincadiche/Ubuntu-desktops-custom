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
  # shellcheck source=lib/ui.sh
  source "$REPO_ROOT/lib/ui.sh"
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
  # shellcheck source=lib/vm_remote.sh
  source "$REPO_ROOT/lib/vm_remote.sh"
  # shellcheck source=lib/orchestrator.sh
  source "$REPO_ROOT/lib/orchestrator.sh"
  # shellcheck source=lib/module_catalog.sh
  source "$REPO_ROOT/lib/module_catalog.sh"
  # shellcheck source=lib/module_adapter.sh
  source "$REPO_ROOT/lib/module_adapter.sh"
  # shellcheck source=lib/app_packaging_inventory.sh
  source "$REPO_ROOT/lib/app_packaging_inventory.sh"
  # shellcheck source=lib/pretest_audit.sh
  source "$REPO_ROOT/lib/pretest_audit.sh"
  # shellcheck source=lib/apply_gate.sh
  source "$REPO_ROOT/lib/apply_gate.sh"

  DRY_RUN="${DRY_RUN:-true}"
  ORCH_RESUME="${ORCH_RESUME:-false}"
  config_load_dir "$REPO_ROOT/config"
  ui_init

  LOG_ROOT="${LOG_ROOT:-$REPO_ROOT/logs}"
  STATE_ROOT="${STATE_ROOT:-$REPO_ROOT/state}"
  REPORT_ROOT="${REPORT_ROOT:-$REPO_ROOT/reports}"
  RUN_ID="${RUN_ID:-$(uw_run_id)}"

  safe_mkdir "$LOG_ROOT"
  safe_mkdir "$STATE_ROOT"
  safe_mkdir "$REPORT_ROOT"
  log_init
  state_init
  orchestrator_reset
  module_catalog_reset

  log_info ENGINE "bootstrap run_id=$RUN_ID dry_run=$DRY_RUN resume=$ORCH_RESUME real_machine_approved=${REAL_MACHINE_APPROVED:-false} real_apply_feature=${REAL_APPLY_FEATURE_ENABLED:-false}"
}
