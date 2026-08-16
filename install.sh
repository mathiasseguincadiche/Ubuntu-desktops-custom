#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:---dry-run}"

case "$MODE" in
  --dry-run|--apply) ;;
  *)
    printf 'Usage: %s [--dry-run|--apply]\n' "$0" >&2
    exit 2
    ;;
esac

# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

if [[ "$MODE" == '--apply' ]]; then
  if ! is_true "${REAL_APPLY_FEATURE_ENABLED:-false}"; then
    printf '%s\n' 'REAL APPLY BLOCKED: feature flag REAL_APPLY_FEATURE_ENABLED=false.' >&2
    exit "$EXIT_SECURITY_BLOCK"
  fi
  if ! apply_gate_require_tty; then
    printf '%s\n' 'REAL APPLY BLOCKED: an interactive TTY is mandatory.' >&2
    exit "$EXIT_SECURITY_BLOCK"
  fi
fi

module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"
module_catalog_validate
for module_id in "${CATALOG_ORDER[@]}"; do
  module_adapter_register "$module_id"
done

if [[ "$MODE" == '--dry-run' ]]; then
  export DRY_RUN=true
  export REAL_MACHINE_APPROVED=false
  printf '%s\n' '=== FULL INSTALLATION ORCHESTRATION / DRY-RUN ==='
  printf 'Modules: %d\n' "${#CATALOG_ORDER[@]}"
  printf '%s\n' 'REAL MACHINE APPLY: BLOCKED'

  if orchestrator_run_all; then
    report="$(orchestrator_report)"
    apply_gate_write_dryrun_proof
    printf '%s\n' 'VERDICT: FULL DRY-RUN PASS'
    printf 'Report: %s\n' "$report"
    exit 0
  else
    rc=$?
    report="$(orchestrator_report)"
    printf 'VERDICT: FULL DRY-RUN FAIL (rc=%d)\n' "$rc" >&2
    printf 'Report: %s\n' "$report" >&2
    exit "$rc"
  fi
fi

printf '%s\n' '=== REAL MACHINE APPLY GATE ==='
printf '%s\n' 'No mutation is allowed until every gate below passes.'

# Hardware/OS preflight is read-only and must succeed on the actual workstation.
ACTIVE_SCOPE="$SCOPE_HOST"
if ! orchestrator_call "${ORCH_PRECHECK[host.preflight]}"; then
  printf '%s\n' 'REAL APPLY BLOCKED: HOST preflight failed.' >&2
  exit "$EXIT_PRECHECK_FAILED"
fi
ACTIVE_SCOPE=''

if ! apply_gate_open_runtime; then
  rc=$?
  printf 'REAL APPLY BLOCKED by final gate (rc=%d).\n' "$rc" >&2
  exit "$rc"
fi

# Every major domain requires an independent operator confirmation.
for scope in "$SCOPE_HOST" "$SCOPE_KVM" "$SCOPE_VM_DEVOPS" "$SCOPE_BACKUP"; do
  apply_gate_confirm_phase "$scope" || {
    rc=$?
    printf 'Execution stopped before phase %s (rc=%d).\n' "$scope" "$rc" >&2
    exit "$rc"
  }
  orchestrator_run_scope "$scope" || exit "$?"

  if [[ "$scope" == "$SCOPE_HOST" ]] && is_true "${REAL_APPLY_VERIFY_APP_PACKAGING_AFTER_HOST:-true}"; then
    if app_packaging_require_posthost_converged; then
      log_info ENGINE 'HOST application packaging is fully converged: planned=0 drift=0 duplicates=0.'
    else
      rc=$?
      printf 'Execution stopped after HOST: application packaging convergence failed (rc=%d).\n' "$rc" >&2
      exit "$rc"
    fi
  fi
done

report="$(orchestrator_report)"
printf '%s\n' 'VERDICT: REAL APPLY COMPLETED - POSTCHECKS REQUIRED'
printf 'Report: %s\n' "$report"
