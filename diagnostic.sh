#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"

engine_bootstrap

diagnostic_rc=0
diagnostic_run || diagnostic_rc=$?

printf '\n'
if app_packaging_inventory_run; then
  cat "$APP_PACKAGING_REPORT"
  printf '\n'
  if (( APP_PACKAGING_DUPLICATES > 0 || APP_PACKAGING_DRIFT > 0 )); then
    printf 'WARN | APP PACKAGING | drift=%d duplicates=%d | review before real APPLY\n' \
      "$APP_PACKAGING_DRIFT" "$APP_PACKAGING_DUPLICATES"
    if (( ${#APP_PACKAGING_ISSUES[@]} > 0 )); then
      printf 'Issues: %s\n' "$(IFS=';'; printf '%s' "${APP_PACKAGING_ISSUES[*]}")"
    fi
  else
    printf 'OK   | APP PACKAGING | no cross-manager duplicate or source drift detected\n'
  fi
  printf 'Packaging report: %s\n' "$APP_PACKAGING_REPORT"
else
  printf 'KO   | APP PACKAGING | packaging policy/inventory could not be evaluated\n' >&2
  (( diagnostic_rc != 0 )) || diagnostic_rc="$EXIT_PRECHECK_FAILED"
fi

exit "$diagnostic_rc"
