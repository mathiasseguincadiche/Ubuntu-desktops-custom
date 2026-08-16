#!/usr/bin/env bash

APP_PACKAGING_TRACKED=0
APP_PACKAGING_CONFORMING=0
APP_PACKAGING_PLANNED=0
APP_PACKAGING_DRIFT=0
APP_PACKAGING_DUPLICATES=0
APP_PACKAGING_PRESERVED=0
APP_PACKAGING_REPORT=''
APP_PACKAGING_ISSUES=()

app_packaging_reset() {
  APP_PACKAGING_TRACKED=0
  APP_PACKAGING_CONFORMING=0
  APP_PACKAGING_PLANNED=0
  APP_PACKAGING_DRIFT=0
  APP_PACKAGING_DUPLICATES=0
  APP_PACKAGING_PRESERVED=0
  APP_PACKAGING_REPORT=''
  APP_PACKAGING_ISSUES=()
}

app_packaging_policy_file() {
  printf '%s\n' "${APP_PACKAGING_POLICY_FILE:-${REPO_ROOT:?}/manifests/host/app-packaging-policy.conf}"
}

app_packaging_preferred_manager() {
  case "${1:-}" in
    apt|vendor-apt|vendor-deb) printf '%s\n' apt ;;
    snap) printf '%s\n' snap ;;
    flatpak) printf '%s\n' flatpak ;;
    *) return 1 ;;
  esac
}

app_packaging_apt_installed() {
  local package="${1:?}"
  [[ "$package" != '-' ]] || return 1
  command -v dpkg-query >/dev/null 2>&1 || return 1
  dpkg-query -W -f='${Status}\n' "$package" 2>/dev/null | grep -Fxq 'install ok installed'
}

app_packaging_snap_installed() {
  local name="${1:?}"
  [[ "$name" != '-' ]] || return 1
  command -v snap >/dev/null 2>&1 || return 1
  snap list "$name" >/dev/null 2>&1
}

app_packaging_flatpak_installed() {
  local app_id="${1:?}"
  [[ "$app_id" != '-' ]] || return 1
  command -v flatpak >/dev/null 2>&1 || return 1
  flatpak info --system "$app_id" >/dev/null 2>&1 || flatpak info --user "$app_id" >/dev/null 2>&1
}

app_packaging_apt_origin_matches() {
  local package="${1:?}" expected="${2:?}" installed_version policy
  [[ "$expected" != '-' ]] || return 0
  command -v apt-cache >/dev/null 2>&1 || return 1
  installed_version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null)" || return 1
  policy="$(apt-cache policy "$package" 2>/dev/null)" || return 1

  awk -v version="$installed_version" -v expected="$expected" '
    {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ /^\*\*\*[[:space:]]+/) {
        sub(/^\*\*\*[[:space:]]+/, "", line)
        split(line, fields, /[[:space:]]+/)
        current=(fields[1] == version)
        next
      }
      field_count=split(line, fields, /[[:space:]]+/)
      if (field_count == 2 && fields[2] ~ /^[0-9]+$/) {
        current=(fields[1] == version)
        next
      }
      if (current && index(line, expected) > 0) {
        found=1
      }
    }
    END { exit(found ? 0 : 1) }
  ' <<< "$policy"
}

app_packaging_flatpak_origin_matches() {
  local app_id="${1:?}" expected="${2:?}" origin
  [[ "$expected" != '-' ]] || return 0
  command -v flatpak >/dev/null 2>&1 || return 1
  origin="$(flatpak info --system --show-origin "$app_id" 2>/dev/null || flatpak info --user --show-origin "$app_id" 2>/dev/null)" || return 1
  [[ "$origin" == "$expected" ]]
}

app_packaging_source_matches() {
  local preferred="${1:?}" apt_package="${2:?}" flatpak_id="${3:?}" source_hint="${4:?}"
  case "$preferred" in
    vendor-apt) app_packaging_apt_origin_matches "$apt_package" "$source_hint" ;;
    flatpak) app_packaging_flatpak_origin_matches "$flatpak_id" "$source_hint" ;;
    *) return 0 ;;
  esac
}

app_packaging_manager_summary() {
  local apt_count='unavailable' snap_count='unavailable' flatpak_system='unavailable' flatpak_user='unavailable'
  if command -v dpkg-query >/dev/null 2>&1; then
    apt_count="$(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | awk 'NF{n++} END{print n+0}')"
  fi
  if command -v snap >/dev/null 2>&1; then
    snap_count="$(snap list 2>/dev/null | awk 'NR>1{n++} END{print n+0}')"
  fi
  if command -v flatpak >/dev/null 2>&1; then
    flatpak_system="$(flatpak list --system --app --columns=application 2>/dev/null | awk 'NF{n++} END{print n+0}')"
    flatpak_user="$(flatpak list --user --app --columns=application 2>/dev/null | awk 'NF{n++} END{print n+0}')"
  fi
  printf 'APT packages=%s | SNAP apps=%s | FLATPAK system=%s user=%s\n' \
    "$apt_count" "$snap_count" "$flatpak_system" "$flatpak_user"
}

app_packaging_report_path() {
  local label="${1:-}" suffix=''
  if [[ -n "$label" ]]; then
    [[ "$label" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || return "${EXIT_INVALID_ARGUMENT:-2}"
    suffix="-$label"
  fi
  printf '%s/%s%s-app-packaging-inventory.txt\n' "${REPORT_ROOT:?}" "${RUN_ID:?}" "$suffix"
}

app_packaging_inventory_run() {
  app_packaging_reset
  local report_label="${1:-}"
  local policy report line app mode preferred apt_package snap_name flatpak_id source_hint rationale
  local preferred_manager installed status installed_count source_status
  policy="$(app_packaging_policy_file)"
  [[ -r "$policy" ]] || return 1

  report="$(app_packaging_report_path "$report_label")" || return "$?"
  APP_PACKAGING_REPORT="$report"

  {
    printf '%s\n' '=== UBUNTU-DESKTOPS-CUSTOM APPLICATION PACKAGING INVENTORY ==='
    [[ -z "$report_label" ]] || printf 'Stage: %s\n' "$report_label"
    printf 'Run ID: %s\n' "$RUN_ID"
    printf 'Policy: %s\n' "$policy"
    printf 'Managers: %s\n\n' "$(app_packaging_manager_summary)"
    printf '%-25s | %-8s | %-10s | %-20s | %-12s | %s\n' 'APPLICATION' 'MODE' 'PREFERRED' 'INSTALLED VIA' 'SOURCE' 'STATUS'
    printf '%s\n' '--------------------------+----------+------------+----------------------+--------------+-------------'

    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -n "$line" && "$line" != \#* ]] || continue
      IFS='|' read -r app mode preferred apt_package snap_name flatpak_id source_hint rationale <<< "$line"
      [[ -n "$app" && -n "$mode" && -n "$preferred" && -n "$source_hint" ]] || return 1
      [[ "$mode" == managed || "$mode" == preserve ]] || return 1
      preferred_manager="$(app_packaging_preferred_manager "$preferred")" || return 1

      if [[ "$preferred" == vendor-apt || "$preferred" == flatpak ]]; then
        [[ "$source_hint" != '-' ]] || return 1
      fi

      APP_PACKAGING_TRACKED=$((APP_PACKAGING_TRACKED + 1))
      installed=''
      installed_count=0
      if app_packaging_apt_installed "$apt_package"; then
        installed="${installed:+$installed,}apt"
        installed_count=$((installed_count + 1))
      fi
      if app_packaging_snap_installed "$snap_name"; then
        installed="${installed:+$installed,}snap"
        installed_count=$((installed_count + 1))
      fi
      if app_packaging_flatpak_installed "$flatpak_id"; then
        installed="${installed:+$installed,}flatpak"
        installed_count=$((installed_count + 1))
      fi
      installed="${installed:-none}"
      source_status='n/a'

      if (( installed_count > 1 )); then
        status='DUPLICATE'
        APP_PACKAGING_DUPLICATES=$((APP_PACKAGING_DUPLICATES + 1))
        APP_PACKAGING_ISSUES+=("$app=duplicate[$installed]->$preferred")
      elif (( installed_count == 0 )); then
        if [[ "$mode" == preserve ]]; then
          status='PRESERVE-ABSENT'
          APP_PACKAGING_PRESERVED=$((APP_PACKAGING_PRESERVED + 1))
        else
          status='PLANNED'
          APP_PACKAGING_PLANNED=$((APP_PACKAGING_PLANNED + 1))
        fi
      elif [[ "$installed" == "$preferred_manager" ]]; then
        if app_packaging_source_matches "$preferred" "$apt_package" "$flatpak_id" "$source_hint"; then
          source_status="${source_hint/-/n/a}"
          if [[ "$mode" == preserve ]]; then
            status='PRESERVED'
            APP_PACKAGING_PRESERVED=$((APP_PACKAGING_PRESERVED + 1))
          else
            status='CONFORMING'
            APP_PACKAGING_CONFORMING=$((APP_PACKAGING_CONFORMING + 1))
          fi
        else
          source_status='MISMATCH'
          status='DRIFT'
          APP_PACKAGING_DRIFT=$((APP_PACKAGING_DRIFT + 1))
          APP_PACKAGING_ISSUES+=("$app=${installed}[source-mismatch]->$preferred")
        fi
      else
        status='DRIFT'
        APP_PACKAGING_DRIFT=$((APP_PACKAGING_DRIFT + 1))
        APP_PACKAGING_ISSUES+=("$app=$installed->$preferred")
      fi

      printf '%-25s | %-8s | %-10s | %-20s | %-12s | %s\n' "$app" "$mode" "$preferred" "$installed" "$source_status" "$status"
      printf '  rationale: %s\n' "$rationale"
    done < "$policy"

    printf '\nSUMMARY: tracked=%d | conforming=%d | planned=%d | preserved=%d | drift=%d | duplicates=%d\n' \
      "$APP_PACKAGING_TRACKED" "$APP_PACKAGING_CONFORMING" "$APP_PACKAGING_PLANNED" \
      "$APP_PACKAGING_PRESERVED" "$APP_PACKAGING_DRIFT" "$APP_PACKAGING_DUPLICATES"
    printf '%s\n' 'READ-ONLY: no package, snap or flatpak was installed, removed, refreshed or migrated.'
  } > "$report"
}

app_packaging_issue_summary() {
  if (( ${#APP_PACKAGING_ISSUES[@]} == 0 )); then
    printf '%s\n' 'none'
    return 0
  fi
  local IFS=';'
  printf '%s\n' "${APP_PACKAGING_ISSUES[*]}"
}

app_packaging_require_preapply_clean() {
  if ! app_packaging_inventory_run preapply; then
    printf '%s\n' 'ERROR: application packaging preflight could not be evaluated.' >&2
    return "${EXIT_PRECHECK_FAILED:-3}"
  fi

  if (( APP_PACKAGING_DRIFT > 0 || APP_PACKAGING_DUPLICATES > 0 )); then
    printf 'ERROR: REAL APPLY blocked by application packaging policy: drift=%d duplicates=%d.\n' \
      "$APP_PACKAGING_DRIFT" "$APP_PACKAGING_DUPLICATES" >&2
    printf 'Issues: %s\n' "$(app_packaging_issue_summary)" >&2
    printf 'Read-only report: %s\n' "$APP_PACKAGING_REPORT" >&2
    printf '%s\n' 'Resolve every conflicting package/source explicitly before REAL APPLY. No mutation has been executed by this gate.' >&2
    return "${EXIT_SECURITY_BLOCK:-8}"
  fi

  printf 'APP PACKAGING PRE-APPLY: CLEAN | planned=%d | drift=0 | duplicates=0\n' "$APP_PACKAGING_PLANNED"
  printf 'Read-only report: %s\n' "$APP_PACKAGING_REPORT"
}

app_packaging_require_posthost_converged() {
  if ! app_packaging_inventory_run posthost; then
    printf '%s\n' 'ERROR: post-HOST application packaging inventory could not be evaluated.' >&2
    return "${EXIT_POSTCHECK_FAILED:-6}"
  fi

  if (( APP_PACKAGING_DRIFT > 0 || APP_PACKAGING_DUPLICATES > 0 || APP_PACKAGING_PLANNED > 0 )); then
    printf 'ERROR: HOST packaging convergence incomplete: planned=%d drift=%d duplicates=%d.\n' \
      "$APP_PACKAGING_PLANNED" "$APP_PACKAGING_DRIFT" "$APP_PACKAGING_DUPLICATES" >&2
    printf 'Issues: %s\n' "$(app_packaging_issue_summary)" >&2
    printf 'Post-HOST report: %s\n' "$APP_PACKAGING_REPORT" >&2
    return "${EXIT_POSTCHECK_FAILED:-6}"
  fi

  printf 'APP PACKAGING POST-HOST: CONVERGED | planned=0 | drift=0 | duplicates=0\n'
  printf 'Post-HOST report: %s\n' "$APP_PACKAGING_REPORT"
}
