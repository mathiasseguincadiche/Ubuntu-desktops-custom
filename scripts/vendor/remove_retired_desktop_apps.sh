#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
command -v timeout >/dev/null 2>&1 || { printf '%s\n' 'ERROR: GNU timeout is required for bounded package-manager probes.' >&2; exit 1; }

PROBE_TIMEOUT_SECONDS="${RETIRED_APP_PROBE_TIMEOUT_SECONDS:-8}"
[[ "$PROBE_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || {
  printf '%s\n' 'ERROR: RETIRED_APP_PROBE_TIMEOUT_SECONDS must be a positive integer.' >&2
  exit 1
}

retired_note() {
  printf '[retired-apps] %s\n' "$*"
}

retired_probe_fail() {
  local manager="$1" rc="$2"
  if [[ "$rc" -eq 124 ]]; then
    printf 'ERROR: %s inventory probe timed out after %ss; refusing to guess package state.\n' \
      "$manager" "$PROBE_TIMEOUT_SECONDS" >&2
  else
    printf 'ERROR: %s inventory probe failed (rc=%s); refusing to guess package state.\n' \
      "$manager" "$rc" >&2
  fi
  return 1
}

# User explicitly retired these applications/integrations from the workstation
# desired state. Package removal only: user profiles, mail data and unrelated
# browser policies are intentionally preserved.

if command -v apt-get >/dev/null 2>&1; then
  apt_remove=()
  for package in thunderbird pdfarranger; do
    if dpkg-query -W -f='${Status}\n' "$package" 2>/dev/null | grep -Fxq 'install ok installed'; then
      apt_remove+=("$package")
      retired_note "APT: $package présent -> suppression prévue."
    else
      retired_note "APT: $package déjà absent."
    fi
  done
  if ((${#apt_remove[@]} > 0)); then
    DEBIAN_FRONTEND=noninteractive apt-get -y remove "${apt_remove[@]}"
  else
    retired_note 'APT: aucune application retirée à supprimer.'
  fi
fi

if command -v snap >/dev/null 2>&1; then
  snap_inventory=''
  if snap_inventory="$(timeout --foreground "${PROBE_TIMEOUT_SECONDS}s" snap list 2>/dev/null)"; then
    :
  else
    rc=$?
    retired_probe_fail Snap "$rc"
    exit 1
  fi

  for snap_name in thunderbird pdfarranger; do
    if awk -v wanted="$snap_name" 'NR > 1 && $1 == wanted { found=1 } END { exit(found ? 0 : 1) }' <<< "$snap_inventory"; then
      retired_note "Snap: $snap_name présent -> suppression prévue."
      snap remove "$snap_name"
    else
      retired_note "Snap: $snap_name déjà absent."
    fi
  done
else
  retired_note 'Snap: gestionnaire absent -> rien à vérifier.'
fi

if command -v flatpak >/dev/null 2>&1; then
  system_flatpaks=''
  if system_flatpaks="$(timeout --foreground "${PROBE_TIMEOUT_SECONDS}s" flatpak list --system --app --columns=application 2>/dev/null)"; then
    :
  else
    rc=$?
    retired_probe_fail 'Flatpak système' "$rc"
    exit 1
  fi

  for app_id in org.mozilla.Thunderbird com.github.jeromerobert.pdfarranger; do
    if grep -Fxq "$app_id" <<< "$system_flatpaks"; then
      retired_note "Flatpak système: $app_id présent -> suppression prévue."
      flatpak uninstall --system -y "$app_id"
    else
      retired_note "Flatpak système: $app_id déjà absent."
    fi
  done

  desktop_user="${SUDO_USER:-}"
  if [[ -n "$desktop_user" && "$desktop_user" != root ]] && id "$desktop_user" >/dev/null 2>&1; then
    user_flatpaks=''
    if user_flatpaks="$(timeout --foreground "${PROBE_TIMEOUT_SECONDS}s" sudo -u "$desktop_user" flatpak list --user --app --columns=application 2>/dev/null)"; then
      :
    else
      rc=$?
      retired_probe_fail "Flatpak utilisateur ($desktop_user)" "$rc"
      exit 1
    fi

    for app_id in org.mozilla.Thunderbird com.github.jeromerobert.pdfarranger; do
      if grep -Fxq "$app_id" <<< "$user_flatpaks"; then
        retired_note "Flatpak utilisateur: $app_id présent -> suppression prévue."
        sudo -u "$desktop_user" flatpak uninstall --user -y "$app_id"
      else
        retired_note "Flatpak utilisateur: $app_id déjà absent."
      fi
    done
  else
    retired_note 'Flatpak utilisateur: aucun utilisateur desktop sudo à contrôler.'
  fi
else
  retired_note 'Flatpak: gestionnaire absent -> rien à vérifier.'
fi

# Remove only the DuckDuckGo settings previously managed by this project.
# Other Firefox/Brave policies remain untouched.
FIREFOX_POLICY='/etc/firefox/policies/policies.json'
BRAVE_DDG_POLICY='/etc/brave/policies/managed/20-duckduckgo.json'
DDG_FIREFOX_ID='jid1-ZAdIEUB7XOzOJw@jetpack'

if [[ -e "$BRAVE_DDG_POLICY" ]]; then
  rm -f -- "$BRAVE_DDG_POLICY"
  retired_note 'Brave: ancienne politique DuckDuckGo supprimée.'
else
  retired_note 'Brave: ancienne politique DuckDuckGo déjà absente.'
fi

if [[ -s "$FIREFOX_POLICY" ]] && command -v jq >/dev/null 2>&1; then
  tmp_policy="$(mktemp)"
  trap 'rm -f -- "${tmp_policy:-}"' EXIT
  jq --arg addon_id "$DDG_FIREFOX_ID" '
    .policies = (.policies // {}) |
    if .policies.SearchEngines?.Default == "DuckDuckGo"
      then del(.policies.SearchEngines.Default)
      else .
    end |
    if ((.policies.SearchEngines? // {}) | length) == 0
      then del(.policies.SearchEngines)
      else .
    end |
    del(.policies.ExtensionSettings[$addon_id]) |
    if ((.policies.ExtensionSettings? // {}) | length) == 0
      then del(.policies.ExtensionSettings)
      else .
    end
  ' "$FIREFOX_POLICY" > "$tmp_policy"
  install -m 0644 "$tmp_policy" "$FIREFOX_POLICY"
  retired_note 'Firefox: politiques gérées vérifiées/nettoyées.'
else
  retired_note 'Firefox: aucune politique gérée à nettoyer.'
fi

retired_note 'Nettoyage terminé : les éléments déjà absents ont été ignorés sans erreur.'
retired_note 'Données utilisateur, profils Thunderbird et politiques non gérées préservés.'
