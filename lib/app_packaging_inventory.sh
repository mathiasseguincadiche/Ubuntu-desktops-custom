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

app_packaging_inventory_run() {
  app_packaging_reset
  local policy report line app mode preferred apt_package snap_name flatpak_id rationale
  local preferred_manager installed status installed_count
  policy="$(app_packaging_policy_file)"
  [[ -r "$policy" ]] || return 1

  report="${REPORT_ROOT:?}/${RUN_ID:?}-app-packaging-inventory.txt"
  APP_PACKAGING_REPORT="$report"

  {
    printf '%s\n' '=== UBUNTU-DESKTOPS-CUSTOM APPLICATION PACKAGING INVENTORY ==='
    printf 'Run ID: %s\n' "$RUN_ID"
    printf 'Policy: %s\n' "$policy"
    printf 'Managers: %s\n\n' "$(app_packaging_manager_summary)"
    printf '%-25s | %-8s | %-10s | %-20s | %s\n' 'APPLICATION' 'MODE' 'PREFERRED' 'INSTALLED VIA' 'STATUS'
    printf '%s\n' '--------------------------+----------+------------+----------------------+-------------'

    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -n "$line" && "$line" != \#* ]] || continue
      IFS='|' read -r app mode preferred apt_package snap_name flatpak_id rationale <<< "$line"
      [[ -n "$app" && -n "$mode" && -n "$preferred" ]] || return 1
      [[ "$mode" == managed || "$mode" == preserve ]] || return 1
      preferred_manager="$(app_packaging_preferred_manager "$preferred")" || return 1

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
        if [[ "$mode" == preserve ]]; then
          status='PRESERVED'
          APP_PACKAGING_PRESERVED=$((APP_PACKAGING_PRESERVED + 1))
        else
          status='CONFORMING'
          APP_PACKAGING_CONFORMING=$((APP_PACKAGING_CONFORMING + 1))
        fi
      else
        status='DRIFT'
        APP_PACKAGING_DRIFT=$((APP_PACKAGING_DRIFT + 1))
        APP_PACKAGING_ISSUES+=("$app=$installed->$preferred")
      fi

      printf '%-25s | %-8s | %-10s | %-20s | %s\n' "$app" "$mode" "$preferred" "$installed" "$status"
      printf '  rationale: %s\n' "$rationale"
    done < "$policy"

    printf '\nSUMMARY: tracked=%d | conforming=%d | planned=%d | preserved=%d | drift=%d | duplicates=%d\n' \
      "$APP_PACKAGING_TRACKED" "$APP_PACKAGING_CONFORMING" "$APP_PACKAGING_PLANNED" \
      "$APP_PACKAGING_PRESERVED" "$APP_PACKAGING_DRIFT" "$APP_PACKAGING_DUPLICATES"
    printf '%s\n' 'READ-ONLY: no package, snap or flatpak was installed, removed, refreshed or migrated.'
  } > "$report"
}
