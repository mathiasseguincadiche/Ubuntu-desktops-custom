#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -t 0 && -t 1 ]] || {
  printf '%s\n' 'PACKAGING REPAIR BLOCKED: an interactive TTY is mandatory.' >&2
  exit 8
}

# shellcheck source=lib/bootstrap.sh
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

printf '%s\n' '=== APPLICATION PACKAGING REMEDIATION / PRE-APPLY ==='
printf '%s\n' 'This path only repairs explicitly supported packaging migrations.'
printf '%s\n' 'It does not open the global REAL APPLY gate.'

app_packaging_inventory_run || {
  printf '%s\n' 'PACKAGING REPAIR BLOCKED: inventory failed.' >&2
  exit "$EXIT_PRECHECK_FAILED"
}
cat "$APP_PACKAGING_REPORT"

if (( APP_PACKAGING_DRIFT == 0 && APP_PACKAGING_DUPLICATES == 0 )); then
  printf '%s\n' 'No packaging remediation is required.'
  exit 0
fi

expected_issue='firefox=duplicate[apt,snap]->vendor-apt'
if (( APP_PACKAGING_DRIFT != 0 || APP_PACKAGING_DUPLICATES != 1 )) || \
   [[ "${#APP_PACKAGING_ISSUES[@]}" -ne 1 || "${APP_PACKAGING_ISSUES[0]}" != "$expected_issue" ]]; then
  printf '%s\n' 'PACKAGING REPAIR BLOCKED: detected issues are not an approved automatic migration.' >&2
  printf 'Issues: %s\n' "${APP_PACKAGING_ISSUES[*]:-none}" >&2
  exit "$EXIT_MANUAL_ACTION_REQUIRED"
fi

printf '%s\n' \
  'Supported migration detected: Firefox Ubuntu transition package + Firefox Snap -> Mozilla APT.' \
  'The Snap profile will be backed up and checksum-verified before package removal.' \
  'The backup is retained after migration.'

confirmation='MIGRER_FIREFOX_SNAP_VERS_MOZILLA_APT'
printf 'Pour autoriser cette migration uniquement, saisir exactement : %s\n' "$confirmation"
read -r -p '> ' answer
[[ "$answer" == "$confirmation" ]] || {
  printf '%s\n' 'PACKAGING REPAIR CANCELLED: confirmation rejected.' >&2
  exit "$EXIT_SECURITY_BLOCK"
}

sudo -v
sudo env DESKTOP_USER="${USER:?}" REPO_ROOT="$REPO_ROOT" \
  bash "$REPO_ROOT/scripts/vendor/migrate_firefox_snap_to_mozilla_apt.sh"

# Re-run the read-only policy inventory after the dedicated migration.
app_packaging_inventory_run || exit "$EXIT_POSTCHECK_FAILED"
cat "$APP_PACKAGING_REPORT"

if (( APP_PACKAGING_DRIFT != 0 || APP_PACKAGING_DUPLICATES != 0 )); then
  printf 'PACKAGING REPAIR FAILED: drift=%d duplicates=%d\n' \
    "$APP_PACKAGING_DRIFT" "$APP_PACKAGING_DUPLICATES" >&2
  exit "$EXIT_POSTCHECK_FAILED"
fi

printf '%s\n' 'PACKAGING REPAIR PASS: drift=0 duplicates=0. Planned applications may now be installed by the normal APPLY.'
