#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:---dry-run}"

case "$MODE" in
  --dry-run)
    export DRY_RUN=true
    export REAL_MACHINE_APPROVED=false
    ;;
  --apply)
    printf '%s\n' 'REAL APPLY DISABLED: final workstation execution approval has not been opened.' >&2
    exit 10
    ;;
  *)
    printf 'Usage: %s [--dry-run|--apply]\n' "$0" >&2
    exit 2
    ;;
esac

# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"
module_catalog_validate
for module_id in "${CATALOG_ORDER[@]}"; do
  module_adapter_register "$module_id"
done

printf '%s\n' '=== FULL INSTALLATION ORCHESTRATION / DRY-RUN ==='
printf 'Modules: %d\n' "${#CATALOG_ORDER[@]}"
printf '%s\n' 'REAL MACHINE APPLY: BLOCKED'

if orchestrator_run_all; then
  report="$(orchestrator_report)"
  printf '%s\n' 'VERDICT: FULL DRY-RUN PASS'
  printf 'Report: %s\n' "$report"
else
  rc=$?
  report="$(orchestrator_report)"
  printf 'VERDICT: FULL DRY-RUN FAIL (rc=%d)\n' "$rc" >&2
  printf 'Report: %s\n' "$report" >&2
  exit "$rc"
fi
