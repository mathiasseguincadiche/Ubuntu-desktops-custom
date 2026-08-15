#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"

engine_bootstrap
module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"
module_catalog_validate

printf '%s\n' '=== Ubuntu-desktops-custom PRE-TEST DIAGNOSTIC ==='
printf 'Run ID: %s\nDry-run: %s\nReal machine approved: %s\n\n' \
  "$RUN_ID" "$DRY_RUN" "${REAL_MACHINE_APPROVED:-false}"

printf '%s\n' 'Execution plan:'
module_catalog_print_plan

printf '\n%s\n' 'Safety gates:'
printf '  REAL_MACHINE_APPROVED=%s\n' "${REAL_MACHINE_APPROVED:-false}"
printf '  DRY_RUN=%s\n' "$DRY_RUN"
printf '  KVM fail-closed=%s\n' "${KVM_FAIL_CLOSED:-unknown}"
printf '  Backup fail-closed=%s\n' "${BACKUP_FAIL_CLOSED:-unknown}"
printf '  External backup target required=%s\n' "${BACKUP_REQUIRE_EXTERNAL_TARGET:-unknown}"
printf '\n%s\n' 'VERDICT: ARCHITECTURE PRE-TEST READY FOR MODULE CONTRACT REVIEW'
